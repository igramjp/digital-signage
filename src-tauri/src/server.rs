use std::{net::SocketAddr, path::PathBuf};

use axum::Router;
use tauri::{AppHandle, Manager};
use tower_http::{
  cors::CorsLayer,
  services::ServeDir,
  set_header::SetResponseHeaderLayer,
};
use axum::http::{header::{CACHE_CONTROL, ACCESS_CONTROL_ALLOW_ORIGIN}, HeaderValue};

#[derive(Clone, Debug)]
pub struct ServerInfo {
  pub port: u16,
  pub base_url: String,
}

/// Try to resolve a local directory for videos.
/// - In dev: ./static/videos
/// - In prod: bundle resources: videos/
fn resolve_videos_dir(app: &AppHandle) -> Option<PathBuf> {
  // Prefer project static directory if exists (dev)
  if let Ok(cwd) = std::env::current_dir() {
    let p = cwd.join("static").join("videos");
    if p.exists() {
      return Some(p);
    }
  }

  // Fallback to bundled resources (prod)
  if let Ok(root) = app.path().resolve("", tauri::path::BaseDirectory::Resource) {
    let p1 = root.join("videos");
    if p1.exists() {
      return Some(p1);
    }
    let p2 = root.join("static").join("videos");
    if p2.exists() {
      return Some(p2);
    }
  }

  None
}

pub async fn spawn_static_server(app: AppHandle) -> Option<ServerInfo> {
  let Some(videos_dir) = resolve_videos_dir(&app) else {
    log::warn!("[static-server] videos directory not found; server not started");
    return None;
  };

  // Allow overriding port via env var; default to 17820
  let port: u16 = std::env::var("LOCAL_STATIC_PORT")
    .ok()
    .and_then(|s| s.parse().ok())
    .unwrap_or(17820);

  // Resolve Cache-Control max-age from env (seconds); default: 3600 (1h)
  let cache_max_age: u64 = std::env::var("LOCAL_STATIC_MAX_AGE")
    .ok()
    .and_then(|s| s.parse().ok())
    .unwrap_or(3600);
  let cache_header = format!("public, max-age={}", cache_max_age);
  let cache_header_val = HeaderValue::from_str(&cache_header)
    .unwrap_or_else(|_| HeaderValue::from_static("public, max-age=3600"));

  // Build a router dedicated to serving videos with headers optimized for media:
  // - CORS open to allow tauri://localhost to access
  // - Cache-Control to enable client-side caching between loads
  // - No compression layer (range requests work best without it for mp4)
  let app_router = Router::new()
    .route_service(
      "/videos/*file",
      ServeDir::new(videos_dir),
    )
    .layer(SetResponseHeaderLayer::if_not_present(CACHE_CONTROL, cache_header_val))
    .layer(SetResponseHeaderLayer::overriding(
      ACCESS_CONTROL_ALLOW_ORIGIN,
      HeaderValue::from_static("*"),
    ))
    .layer(CorsLayer::permissive());

  // Bind to 127.0.0.1:port
  let addr: SocketAddr = SocketAddr::from(([127, 0, 0, 1], port));
  let listener = match tokio::net::TcpListener::bind(addr).await {
    Ok(l) => l,
    Err(e) => {
      log::error!("[static-server] failed to bind {}: {}", addr, e);
      return None;
    }
  };
  let server = axum::serve(listener, app_router.into_make_service());

  // Spawn without blocking Tauri
  tauri::async_runtime::spawn(async move {
    if let Err(e) = server.await {
      log::error!("[static-server] server error: {e}");
    }
  });

  let info = ServerInfo {
    port,
    base_url: format!("http://127.0.0.1:{port}"),
  };

  Some(info)
}
