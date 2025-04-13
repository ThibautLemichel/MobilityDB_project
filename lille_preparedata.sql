-------------------------------------------------------------------------------
-- Prepare the BerlinMOD generator using the OSM data from Brussels
-------------------------------------------------------------------------------
 
-- We need to convert the resulting data in Spherical Mercator (SRID = 3857)
-- We create two tables for that

DROP TABLE IF EXISTS RoadSegments;
CREATE TABLE RoadSegments(segmentId bigint PRIMARY KEY, name text, 
  osm_id bigint, tag_id integer, segmentLength float, sourceNode bigint, 
  targetNode bigint, source_osm bigint, target_osm bigint, cost_s float,
  reverse_cost_s float, one_way integer, maxSpeedFwd float, maxSpeedBwd float, 
  priority float, segmentGeo geometry);
INSERT INTO RoadSegments(SegmentId, name, osm_id, tag_id, segmentLength, 
  sourceNode, targetNode, source_osm, target_osm, cost_s, reverse_cost_s, 
  one_way, maxSpeedFwd, maxSpeedBwd, priority, segmentGeo)
SELECT gid, name, osm_id, tag_id, length_m, source, target, source_osm,
  target_osm, cost_s, reverse_cost_s, one_way, maxspeed_forward,
  maxspeed_backward, priority, ST_Transform(the_geom, 3857)
FROM ways;

-- The nodes table should contain ONLY the vertices that belong to the largest
-- connected component in the underlying map. Like this, we guarantee that
-- there will be a non-NULL shortest path between any two nodes.
DROP TABLE IF EXISTS Nodes;
CREATE TABLE Nodes(id bigint PRIMARY KEY, osm_id bigint, geom geometry);
INSERT INTO Nodes(id, osm_id, geom)
WITH Components AS (
  SELECT * FROM pgr_strongComponents(
    'SELECT segmentId AS id, sourceNode AS source, targetNode AS target, '
    'segmentLength AS cost, segmentLength * sign(reverse_cost_s) AS reverse_cost '
    'FROM RoadSegments') ),
LargestComponent AS (
  SELECT component, COUNT(*) FROM Components
  GROUP BY component ORDER BY COUNT(*) DESC LIMIT 1),
Connected AS (
  SELECT id, osm_id, the_geom AS geom
  FROM ways_vertices_pgr W, LargestComponent L, Components C
  WHERE W.id = C.node AND C.component = L.component
)
SELECT ROW_NUMBER() OVER (), osm_id, ST_Transform(geom, 3857) AS geom
FROM Connected;

CREATE UNIQUE INDEX Nodes_id_idx ON Nodes USING BTREE(id);
CREATE INDEX Nodes_osm_id_idx ON Nodes USING BTREE(osm_id);
CREATE INDEX Nodes_geom_idx ON NODES USING GiST(geom);

UPDATE RoadSegments R SET
sourceNode = (SELECT id FROM Nodes N WHERE N.osm_id = R.source_osm),
targetNode = (SELECT id FROM Nodes N WHERE N.osm_id = R.target_osm);

-- Delete the edges whose source or target node has been removed
DELETE FROM RoadSegments WHERE sourceNode IS NULL OR targetNode IS NULL;

CREATE INDEX RoadSegments_segmentGeo_index ON RoadSegments USING GiST(segmentGeo);

/*
-- The following were obtained FROM the OSM file extracted on March 26, 2023
SELECT COUNT(*) FROM RoadSegments;
-- 95025
SELECT COUNT(*) FROM Nodes;
-- 80304
*/

-------------------------------------------------------------------------------
-- Get municipalities data to define home and work regions
-------------------------------------------------------------------------------

-- Brussels' municipalities data from the following sources
-- https://en.wikipedia.org/wiki/List_of_municipalities_of_the_Brussels-Capital_Region
-- http://ibsa.brussels/themes/economie

DROP TABLE IF EXISTS Municipalities;
CREATE TABLE Municipalities(MunicipalityId int PRIMARY KEY, 
  MunicipalityName text, Population int, PercPop float, PopDensityKm2 int, 
  NoEnterp int, PercEnterp float);
INSERT INTO Municipalities VALUES
(1,'Lille-Moulins',19991,0.12,11168,1230,0.05),
(2,'Wazemmes',27515,0.09,16476,980,0.04),
(3,'Lille-Centre', 28917,0.06,9512,620,0.03),
(4,'Fives',21025,0.09,6893,850,0.04),
(5,'Vieux-Lille',18772,0.08,10147,1000,0.05),
(6,'Saint-Maurice Pellevoisin',17031,0.09,8779,990,0.06),
(7,'Faubourg de Béthune',7621,0.10,7056,750,0.02),
(8,'Lille-Sud',20916,0.12,6063,650,0.05),
(9,'Bois Blancs',8951,0.08,5115,1180,0.03),
(10,'Vauban-Esquermes',18772,0.07,7954,870,0.04);




-- Compute the geometry of the Municipalities from the boundaries in planet_osm_line

/*
DROP TABLE IF EXISTS MunicipalitiesGeo;
CREATE TABLE MunicipalitiesGeo(Name, Geom) AS
SELECT Name, Way
FROM planet_osm_line L
WHERE Name IN ( SELECT MunicipalityName FROM Municipalities );

-- The geometries of the Municipalities are of type Linestring. They need to be
-- converted into polygons.

ALTER TABLE MunicipalitiesGeo ADD COLUMN GeomPoly geometry;
UPDATE MunicipalitiesGeo
SET GeomPoly = ST_MakePolygon(geom);
*/

DROP TABLE IF EXISTS MunicipalitiesGeo;
CREATE TABLE MunicipalitiesGeo(Name, GeomPoly) AS
SELECT name, way
FROM planet_osm_polygon
WHERE boundary = 'administrative' AND admin_level = '10'
AND name IN (SELECT MunicipalityName FROM Municipalities);

-- Disjoint components of Ixelles and Saint-Gilles are encoded as two different
-- features. For this reason ST_Union is needed to make a multipolygon
ALTER TABLE Municipalities ADD COLUMN MunicipalityGeo geometry;
UPDATE Municipalities m
SET MunicipalityGeo = (
  SELECT ST_Union(GeomPoly) FROM MunicipalitiesGeo g
  WHERE m.MunicipalityName = g.Name);

CREATE INDEX Municipalities_MunicipalityGeo_idx ON Municipalities 
USING GiST(MunicipalityGeo);

-- Clean up tables
DROP TABLE IF EXISTS MunicipalitiesGeo;

-- Create home/work regions and nodes

DROP TABLE IF EXISTS HomeRegions;
CREATE TABLE HomeRegions(id, priority, weight, prob, cumulProb, geom) AS
SELECT MunicipalityId, MunicipalityId, population, PercPop,
  SUM(PercPop) OVER (ORDER BY MunicipalityId ASC ROWS 
    BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulProb, MunicipalityGeo
FROM Municipalities;

CREATE INDEX HomeRegions_geom_idx ON HomeRegions USING GiST(geom);

DROP TABLE IF EXISTS WorkRegions;
CREATE TABLE WorkRegions(id, priority, weight, prob, cumulProb, geom) AS
SELECT MunicipalityId, MunicipalityId, NoEnterp, PercEnterp,
  SUM(PercEnterp) OVER (ORDER BY MunicipalityId ASC ROWS
    BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulProb, MunicipalityGeo
FROM Municipalities;

CREATE INDEX WorkRegions_geom_idx ON WorkRegions USING GiST(geom);

DROP TABLE IF EXISTS HomeNodes;
CREATE TABLE HomeNodes AS
SELECT T1.*, T2.id AS region, T2.CumulProb
FROM Nodes T1, HomeRegions T2
WHERE ST_Intersects(T2.geom, T1.geom);

CREATE INDEX HomeNodes_id_idx ON HomeNodes USING BTREE (id);

DROP TABLE IF EXISTS WorkNodes;
CREATE TABLE WorkNodes AS
SELECT T1.*, T2.id AS region
FROM Nodes T1, WorkRegions T2
WHERE ST_Intersects(T1.geom, T2.geom);

CREATE INDEX WorkNodes_id_idx ON WorkNodes USING BTREE (id);

-------------------------------------------------------------------------------
-- THE END
-------------------------------------------------------------------------------
