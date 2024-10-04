use clap::Parser;
use fetcher::Fetcher;
use warp::Filter;

#[derive(Debug, Parser)]
#[command(version, about)]
struct Arguments {
    /// The address to bind to.
    #[arg(long, env, default_value = "127.0.0.1:3030")]
    address: String,

    /// Registry URL to connect to. Example [http://127.0.0.1:3030]
    #[arg(long, env)]
    registry_url: String,

    /// Registry username and password separated with a colon. Example [username:password]
    #[arg(long, env)]
    registry_credentials: Option<Credentials>,
}

#[derive(Debug, Clone)]
struct Credentials {
    username: String,
    password: String,
}

impl std::str::FromStr for Credentials {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let parts: Vec<&str> = s.split(':').collect();
        if parts.len() != 2 {
            return Err("credentials must be in the format 'username:password'".to_string());
        }
        Ok(Credentials {
            username: parts[0].to_string(),
            password: parts[1].to_string(),
        })
    }
}

#[tokio::main]
async fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;

    let filter = std::env::var("RUST_LOG")
        .unwrap_or_else(|_| "tracing=info,warp=debug,octopod=debug".to_owned());
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_span_events(tracing_subscriber::fmt::format::FmtSpan::CLOSE)
        .init();

    let args = Arguments::parse();

    let fetcher = Fetcher::new(args.registry_url, args.registry_credentials);
    fetcher.check_auth().await?;

    let routes = statics::main_js()
        .or(statics::files())
        .or(api::hander(fetcher))
        .or(statics::index_html());

    let address = args.address.parse::<std::net::SocketAddr>()?;
    warp::serve(routes).run(address).await;

    Ok(())
}

mod statics {
    use std::path::Path;

    use include_dir::{include_dir, Dir};
    use warp::{
        http::{
            header::{CACHE_CONTROL, CONTENT_TYPE},
            Response,
        },
        Filter,
    };

    pub fn index_html(
    ) -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone {
        const INDEX_HTML: &str = include_str!("../ui/index.html");

        warp::get().map(|| {
            Response::builder()
                .header(CONTENT_TYPE, "text/html")
                .body(INDEX_HTML)
                .unwrap()
        })
    }

    pub fn main_js() -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone
    {
        const MAIN_JS: &str = include_str!("../ui/Main.js");

        warp::path!("Main.js").map(|| {
            Response::builder()
                .header(CONTENT_TYPE, "text/javascript")
                .body(MAIN_JS)
                .unwrap()
        })
    }

    static STATIC_DIR: Dir = include_dir!("statics");

    async fn send_file(path: warp::path::Tail) -> Result<impl warp::Reply, warp::Rejection> {
        let path = Path::new(path.as_str());
        let file = STATIC_DIR
            .get_file(path)
            .ok_or_else(warp::reject::not_found)?;

        let content_type = match file.path().extension() {
            Some(ext) if ext == "css" => "text/css",
            Some(ext) if ext == "svg" => "image/svg+xml",
            Some(ext) if ext == "js" => "text/javascript",
            Some(ext) if ext == "html" => "text/html",
            _ => "application/octet-stream",
        };

        let resp = Response::builder()
            .header(CONTENT_TYPE, content_type)
            .header(CACHE_CONTROL, "max-age=3600, must-revalidate")
            .body(file.contents())
            .unwrap();

        Ok(resp)
    }

    pub fn files() -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone {
        warp::get()
            .and(warp::path::path("statics"))
            .and(warp::path::tail())
            .and_then(send_file)
    }
}

mod fetcher {
    use reqwest::Client;

    use crate::Credentials;

    #[derive(Clone)]
    pub struct Fetcher {
        client: Client,
        url: String,
        auth: Option<Credentials>,
    }

    impl Fetcher {
        pub fn new(url: String, auth: Option<Credentials>) -> Self {
            Self {
                client: Client::new(),
                url,
                auth,
            }
        }

        pub async fn fetch(&self, url: &str) -> color_eyre::Result<serde_json::Value> {
            let req = self.client.get(format!("{}/{url}", self.url));

            let resp = match &self.auth {
                Some(Credentials { username, password }) => {
                    req.basic_auth(username, Some(password))
                }
                None => req,
            }
            .send()
            .await?
            .json()
            .await?;

            Ok(resp)
        }

        pub async fn check_auth(&self) -> color_eyre::Result<()> {
            let resp = self.fetch("v2").await?;

            if resp == serde_json::json!({}) {
                tracing::info!("registry connection check succeeded");
                Ok(())
            } else {
                color_eyre::eyre::bail!("registry connection check failed")
            }
        }
    }
}

mod api {
    use warp::Filter;

    use crate::fetcher::Fetcher;

    async fn send_request(
        fetcher: Fetcher,
        path: warp::path::Tail,
    ) -> Result<impl warp::Reply, warp::Rejection> {
        match fetcher.fetch(path.as_str()).await {
            Ok(json) => Ok(warp::reply::json(&json)),
            Err(error) => {
                tracing::error!(
                    "encountered an error sending request to server: {path:?} {error:?}"
                );
                Err(warp::reject())
            }
        }
    }

    pub fn hander(
        fetcher: Fetcher,
    ) -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone {
        warp::get()
            .and(warp::path::path("api"))
            .and(warp::any().map(move || fetcher.clone()))
            .and(warp::path::tail())
            .and_then(send_request)
    }
}
