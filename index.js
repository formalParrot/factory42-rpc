import "dotenv/config";
import RPC from "discord-rpc";

const CLIENT_ID = "1548254736782991490";
const API_URL = "https://api.justparrot.me/f42/services/survival";

const rpc = new RPC.Client({
  transport: "ipc"
});

let connected = false;

async function getServerStatus() {
  const response = await fetch(API_URL, {
    headers: {
      'Content-Type': 'application/json',
      'x-webhook-token': process.env.FACTORY_42_TOKEN,
    }
  });

  if (!response.ok) {
    throw new Error(`API returned HTTP ${response.status}`);
  }

  return response.json();
}

async function updatePresence() {
  try {
    const server = await getServerStatus();

    if (!server.running) {
      rpc.setActivity({
        details: "Factory 42 SMP",
        state: "Survival server offline",
        largeImageKey: "factory42",
        largeImageText: "Factory 42 SMP"
      });

      console.log("[RPC] Survival is offline");
      return;
    }

    const playerCount = server.playerCount ?? 0;

    rpc.setActivity({
      details: "Playing Factory 42",
      state: `${playerCount} player${playerCount === 1 ? "" : "s"} online`,
      largeImageKey: "factory42",
      largeImageText: "Factory 42 SMP"
    });

    console.log(
      `[RPC] Survival online: ${playerCount} player${playerCount === 1 ? "" : "s"}`
    );
  } catch (error) {
    console.error("[RPC] Failed to update:", error.message);
  }
}

function connect() {
  if (connected) return;

  rpc.login({
    clientId: CLIENT_ID
  }).catch((error) => {
    console.error("[RPC] Discord connection failed:", error.message);
    console.log("[RPC] Retrying in 10 seconds...");
    setTimeout(connect, 10_000);
  });
}

rpc.on("ready", async () => {
  connected = true;

  console.log("[RPC] Connected to Discord");

  await updatePresence();

  setInterval(updatePresence, 30_000);
});

rpc.on("disconnected", () => {
  connected = false;

  console.log("[RPC] Discord disconnected");
  console.log("[RPC] Retrying in 10 seconds...");

  setTimeout(connect, 10_000);
});

console.log("[RPC] Starting Factory 42 Rich Presence...");
connect();
