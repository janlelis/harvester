create table items (
  rss varchar(255) not null,
  title varchar(255),
  link varchar(255),
  date timestamp,
  description text,
  unique (rss(166), link(166))
);
