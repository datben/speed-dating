use async_std::sync::{Arc, Mutex};
use tide::prelude::*;
use tide::Request;

struct Markets {
    market1: Mutex<Orderbook>,
    market2: Mutex<Orderbook>,
    market3: Mutex<Orderbook>,
}

impl Markets {
    async fn get_market(&self, market_id: u64) -> Option<Orderbook> {
        match market_id {
            1 => self.market1.lock().await.clone().into(),
            2 => self.market2.lock().await.clone().into(),
            3 => self.market3.lock().await.clone().into(),
            _ => None,
        }
    }

    async fn place_order(&self, market_id: u64, order: Order, is_buy: bool) {
        match market_id {
            1 => self.market1.lock().await.place_order(order, is_buy),
            2 => self.market2.lock().await.place_order(order, is_buy),
            3 => self.market3.lock().await.place_order(order, is_buy),
            _ => (),
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct Orderbook {
    base: String,
    quote: String,
    bids: Vec<Order>, // buy base
    asks: Vec<Order>, // sell base
    price_decimals: u8,
}

impl Orderbook {
    pub fn new(base: String, quote: String, price_decimals: u8) -> Self {
        Orderbook {
            base,
            quote,
            bids: Vec::new(),
            asks: Vec::new(),
            price_decimals,
        }
    }

    pub fn place_order(&mut self, order: Order, is_buy: bool) {
        if is_buy {
            self.bids.push(order)
        } else {
            self.asks.push(order)
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct Order {
    order_id: String,
    price: u64,
    quantity: u64,
}

///
///
///  curl localhost:8080/markets/1
///  curl localhost:8080/markets/1/buy/100/12
///  curl localhost:8080/markets/1/sell/100/12
///
#[async_std::main]
async fn main() -> tide::Result<()> {
    let mut app = tide::new();
    let market = Arc::new(Markets {
        market1: Mutex::new(Orderbook::new("A".into(), "B".into(), 3)),
        market2: Mutex::new(Orderbook::new("B".into(), "C".into(), 3)),
        market3: Mutex::new(Orderbook::new("C".into(), "A".into(), 3)),
    });
    let m1 = market.clone();
    let m2 = market.clone();
    let m3 = market.clone();

    app.at("/markets/:id")
        .get(move |r| get_market(r, m1.clone()));
    app.at("/markets/:id/buy/:price/:quantity")
        .get(move |r| place_order(r, m2.clone(), true));
    app.at("/markets/:id/sell/:price/:quantity")
        .get(move |r| place_order(r, m3.clone(), false));
    app.listen("127.0.0.1:8080").await?;
    Ok(())
}

async fn get_market(req: Request<()>, markets: Arc<Markets>) -> tide::Result {
    if let Some(market_id) = req.param("id").ok().and_then(|str| str.parse::<u64>().ok()) {
        Ok(
            serde_json::to_string(&markets.clone().get_market(market_id).await.unwrap())
                .ok()
                .unwrap()
                .into(),
        )
    } else {
        Ok("Failed to parse request".into())
    }
}

async fn place_order(req: Request<()>, markets: Arc<Markets>, is_buy: bool) -> tide::Result {
    let (market_id, order) = extract_order(req);
    markets.clone().place_order(market_id, order, is_buy).await;
    Ok("ok".into())
}

fn extract_order(req: Request<()>) -> (u64, Order) {
    let market_id = req
        .param("id")
        .ok()
        .and_then(|str| str.parse::<u64>().ok())
        .unwrap();
    let price = req
        .param("price")
        .ok()
        .and_then(|str| str.parse::<u64>().ok())
        .unwrap();
    let quantity = req
        .param("quantity")
        .ok()
        .and_then(|str| str.parse::<u64>().ok())
        .unwrap();
    let order = Order {
        order_id: "1".into(),
        price,
        quantity,
    };
    (market_id, order)
}
