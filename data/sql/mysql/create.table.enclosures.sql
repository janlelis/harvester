create table enclosures (
  rss varchar(255) not null,
  link varchar(255) not null,
  href varchar(255) not null,
  mime varchar(255),
  title varchar(255),
  length int,
  unique (rss(100), link(100), href(100))
);
