create view last48hrs as select items.rss, items.title, items.link, sources.title as blogtitle, sources.collection from items, sources where items.rss = sources.rss and now() - interval '48 hour' < items.date order by date;