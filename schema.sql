CREATE TABLE lists (
  id serial PRIMARY KEY,
  name varchar(255) UNIQUE NOT NULL
  );

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name varchar(255),
  list_id integer NOT NULL REFERENCES lists (id) ON DELETE CASCADE,
  completed boolean NOT NULL DEFAULT false
  );