create table sources (
  collection varchar(255) not null,
  rss varchar(255) not null,
  last varchar(40),
  title varchar(255),
  link varchar(255),
  description text,
  unique (collection, rss)
);
