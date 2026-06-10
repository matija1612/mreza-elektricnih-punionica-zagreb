
//  Ograničenja jedinstvenosti
CREATE CONSTRAINT punionica_id IF NOT EXISTS
FOR (p:Punionica)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT tip_naziv IF NOT EXISTS
FOR (t:TipUticnice)
REQUIRE t.naziv IS UNIQUE;

// Učitavanje podataka iz CSV datoteke

LOAD CSV WITH HEADERS
FROM 'https://opendata.arcgis.com/api/v3/datasets/4a4fc728724b4d319c27a9f647a0bb62_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1'
AS row

MERGE (p:Punionica {id: toInteger(row.OBJECTID_1)})

SET p.naziv = row.NAZIV,
    p.name = row.NAZIV,
    p.adresa = row.ADRESA,
    p.lat = toFloat(row.Y),
    p.lon = toFloat(row.X),
    p.broj_uticnica = toInteger(row.BROJ_UTICNICA),
    p.tip_uticnice = row.TIP_UTICNICE;

// Kreiranje AC/DC čvora i relacije IMA_TIP
MATCH (p:Punionica)
UNWIND split(p.tip_uticnice, ',') AS tip
WITH p, trim(tip) AS tipNaziv
WHERE tipNaziv <> ''
MERGE (t:TipUticnice {naziv: tipNaziv})
SET t.name = tipNaziv
MERGE (p)-[:IMA_TIP]->(t);
MATCH (p:Punionica)
REMOVE p.tip_uticnice;

// Kreiranje relacija POVEZANA_S između punionica udaljenih najviše 3 km
MATCH (a:Punionica), (b:Punionica)
WHERE a.id < b.id
WITH a, b,
     point.distance(
        point({latitude: a.lat, longitude: a.lon}),
        point({latitude: b.lat, longitude: b.lon})
     ) / 1000 AS udaljenost_km
WHERE udaljenost_km <= 3
MERGE (a)-[r:POVEZANA_S]->(b)
SET r.udaljenost_km = round(udaljenost_km * 100) / 100;

// Provjera broja punionica
MATCH (p:Punionica)
RETURN count(p) AS broj_punionica;

// Provjera broja prostornih veza
MATCH ()-[r:POVEZANA_S]->()
RETURN count(r) AS broj_veza;

// Graf
MATCH (p:Punionica)
OPTIONAL MATCH (p)-[r1:IMA_TIP]->(t:TipUticnice)
OPTIONAL MATCH (p)-[r2:POVEZANA_S]-(p2:Punionica)
RETURN p, r1, t, r2, p2;

// Upit: najbliže punionice zadanoj lokaciji
MATCH (p:Punionica)
WITH p,
point.distance(
  point({latitude: 45.768984481, longitude: 15.934266084}),
  point({latitude: p.lat, longitude: p.lon})
) / 1000 AS udaljenost_km
RETURN p.naziv AS punionica,
       round(udaljenost_km * 100) / 100 AS udaljenost_km
ORDER BY udaljenost_km
LIMIT 5;

// Upit: najbliže DC punionice
MATCH (p:Punionica)-[:IMA_TIP]->(:TipUticnice {naziv:'DC'})
WITH p,
point.distance(
  point({latitude: 45.768984481, longitude: 15.934266084}),
  point({latitude: p.lat, longitude: p.lon})
) / 1000 AS udaljenost_km
RETURN p.naziv AS punionica,
       p.adresa AS adresa,
       round(udaljenost_km * 100) / 100 AS udaljenost_km
ORDER BY udaljenost_km
LIMIT 5;

// Upit: najpovezanije punionice u mreži
MATCH (p:Punionica)-[r:POVEZANA_S]-()
RETURN p.naziv AS punionica,
       count(r) AS broj_veza
ORDER BY broj_veza DESC
LIMIT 10;

// Upit: najkraći povezani put između dvije punionice
MATCH (start:Punionica {naziv:'HR050130'}),
      (cilj:Punionica {naziv:'GARAŽA KVATRIČ'})
MATCH p = shortestPath((start)-[:POVEZANA_S*]-(cilj))
RETURN p;
