select date(items.date) as date,sources.collection from items left join sources on sources.rss=items.rss where date > time('now', '-14 days') and date < time('now', '+1 day') order by date
