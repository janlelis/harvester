create table sources (
  collection varchar(255) not null,
  rss varchar(255) not null,
  last varchar(40),
  title varchar(255),
  link varchar(255),
  description text,
  unique (collection(166), rss(166))
);

create table items (
  rss varchar(255) not null,
  title varchar(255),
  link varchar(255),
  date timestamp,
  description text,
  unique (rss(166), link(166))
);

create table enclosures (
  rss varchar(255) not null,
  link varchar(255) not null,
  href varchar(255) not null,
  mime varchar(255),
  title varchar(255),
  length int,
  unique (rss(100), link(100), href(100))
);

create view last48hrs as select items.rss, items.title, items.link, sources.title as blogtitle, sources.collection from items, sources where items.rss = sources.rss and now() - interval 48 hour < items.`date` order by date;

create table jabbersubscriptions (
  jid varchar(255) not null,
  collection varchar(255) not null,
  unique (jid(166), collection(166))
);

create table jabbersettings (
  jid varchar(255) primary key,
  respect_status boolean,
  message_type varchar(16)
);
