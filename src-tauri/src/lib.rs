#[cfg_attr(mobile, tauri::mobile_entry_point)]
mod server;
use tauri::Manager;

#[tauri::command]
async fn server_base_url(
  state: tauri::State<'_, tokio::sync::RwLock<Option<server::ServerInfo>>>,
) -> Result<String, String> {
  let read = state.read().await;
  read
    .as_ref()
    .map(|s| s.base_url.clone())
    .ok_or_else(|| "server not started".to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .plugin(tauri_plugin_process::init())
    .invoke_handler(tauri::generate_handler![server_base_url])
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }

      // State to share server info with frontend commands
      let server_state: tokio::sync::RwLock<Option<server::ServerInfo>> =
        tokio::sync::RwLock::new(None);
      app.manage(server_state);

      // Spawn local static server for videos, then write info to state
      let app_handle = app.handle().clone();
      tauri::async_runtime::spawn(async move {
        if let Some(info) = server::spawn_static_server(app_handle.clone()).await {
          log::info!("[static-server] started at {}", info.base_url);
          let state_handle = app_handle.state::<tokio::sync::RwLock<Option<server::ServerInfo>>>();
          let mut write = state_handle.write().await;
          *write = Some(info);
        }
      });

      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
