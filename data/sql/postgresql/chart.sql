select date(items.date) as date,sources.collection from items left join sources on sources.rss=items.rss where date > now() - interval '14 days' and date < now() + interval '1 day' order by date
