const {WebSocket} = require("ws");
const target = process.env.ALBA_RELAY_URL || "wss://albadeacero-juego.onrender.com";
const clients = [];
async function connect(){
 const socket = new WebSocket(target); clients.push(socket);
 const inbox = []; socket.on("message", raw => inbox.push(JSON.parse(raw)));
 await new Promise((resolve,reject)=>{socket.once("open",resolve);socket.once("error",reject);setTimeout(()=>reject(new Error("Public WebSocket timeout")),75000).unref();});
 return {socket,inbox};
}
async function wait(client,type){
 const until=Date.now()+15000;
 while(Date.now()<until){const i=client.inbox.findIndex(m=>m.type===type);if(i>=0)return client.inbox.splice(i,1)[0];await new Promise(r=>setTimeout(r,50));}
 throw new Error("Missing "+type);
}
(async()=>{
 const host=await connect();host.socket.send(JSON.stringify({type:"create"}));const room=await wait(host,"created");
 const guests=[];
 for(let i=1;i<=3;i++){const g=await connect();g.socket.send(JSON.stringify({type:"join",code:room.code}));const joined=await wait(g,"joined");if(joined.slot!==i)throw new Error("Slot mismatch");guests.push(g);}
 host.socket.send(JSON.stringify({type:"start",config:{test:true}}));
 for(const g of guests)await wait(g,"start");
 for(let i=0;i<3;i++)guests[i].socket.send(JSON.stringify({type:"input",seq:1,data:{move_right:true}}));
 for(let i=0;i<3;i++)await wait(host,"input");
 host.socket.send(JSON.stringify({type:"snapshot",data:{floor:2,phase:"transit",cabin:[0,1,2,3]}}));
 for(const g of guests){const m=await wait(g,"snapshot");if(m.data.floor!==2)throw new Error("State mismatch");}
 console.log("PUBLIC RELAY: four slots, start, independent inputs and elevator state forwarded successfully");
})().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(()=>{for(const c of clients)c.close();setTimeout(()=>{for(const c of clients)c.terminate();},1000).unref();});
