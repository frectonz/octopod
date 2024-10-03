use clap::Parser;
use warp::Filter;

#[derive(Debug, Parser)]
#[command(version, about)]
struct Arguments {
    /// The address to bind to.
    #[arg(long, default_value = "127.0.0.1:3030")]
    address: String,

    /// Registry URL to connect to. Example [http://127.0.0.1:3030]
    #[arg(long)]
    registry_url: String,

    /// Registry username and password separated with a colon. Example [username:password]
    #[arg(long)]
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
    dbg!(&args);

    let index_html = statics::get_index_html()?;
    let homepage = statics::homepage(index_html);
    let static_files = statics::routes();

    let routes = static_files.or(homepage);

    let address = args.address.parse::<std::net::SocketAddr>()?;
    warp::serve(routes).run(address).await;

    Ok(())
}

mod statics {
    use std::path::Path;

    use color_eyre::eyre::OptionExt;
    use include_dir::{include_dir, Dir};
    use warp::{
        http::{
            header::{CACHE_CONTROL, CONTENT_TYPE},
            Response,
        },
        Filter,
    };

    static STATIC_DIR: Dir = include_dir!("ui/dist");

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

    pub fn get_index_html() -> color_eyre::Result<String> {
        let file = STATIC_DIR
            .get_file("index.html")
            .ok_or_eyre("could not find index.html")?;

        Ok(file
            .contents_utf8()
            .ok_or_eyre("contents of index.html is not utf-8")?
            .to_owned())
    }

    pub fn homepage(
        file: String,
    ) -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone {
        warp::get()
            .and(warp::any().map(move || file.clone()))
            .map(|file| {
                Response::builder()
                    .header(CONTENT_TYPE, "text/html")
                    .body(file)
                    .unwrap()
            })
    }

    pub fn routes() -> impl Filter<Extract = (impl warp::Reply,), Error = warp::Rejection> + Clone {
        warp::path::tail().and_then(send_file)
    }
}
