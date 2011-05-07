create table jabbersubscriptions (
  jid varchar(255) not null,
  collection varchar(255) not null,
  unique (jid(166), collection(166))
);
