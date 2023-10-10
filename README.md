# speed-dating

Little marketplace to trade with other people

## API

- /api/market -> get market info
- /api/market/{market_id}/{is_buy}/{quantity}/{price}/{user_id}/{pwd} -> place a buy (``is_buy`` == 0) or a sell (``is_buy == 1``) order on market ``markted_id``, return the id of the order
- /api/user/balance/{user_id} -> get balance of ``used_id``
- /api/user/create/{pwd} -> create a new user with password ``pwd``, return the used_id created
