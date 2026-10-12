const assert=require("node:assert/strict");
const {WebSocket}=require("ws");
const {createRelay}=require("./relay.cjs");
const relay=createRelay(0,"127.0.0.1");
const once=(socket,type)=>new Promise((resolve,reject)=>{
  const timeout=setTimeout(()=>reject(Error("Timeout "+type)),3000);
  const handler=raw=>{const p=JSON.parse(raw);if(p.type===type){clearTimeout(timeout);socket.off("message",handler);resolve(p);}};
  socket.on("message",handler);
});
const connect=url=>new Promise(resolve=>{const socket=new WebSocket(url);socket.on("open",()=>resolve(socket));});
(async()=>{
 await new Promise(r=>relay.server.on("listening",r));
 const url="ws://127.0.0.1:"+relay.server.address().port;
 const host=await connect(url), guests=await Promise.all([connect(url),connect(url),connect(url)]), outsider=await connect(url);
 let wait=once(host,"created");host.send(JSON.stringify({type:"create"}));const room=await wait;
 assert.match(room.code,/^[A-F0-9]{6}$/);
 for(let i=0;i<3;i++){
   const joined=once(guests[i],"joined"),peer=once(host,"peer_joined");
   guests[i].send(JSON.stringify({type:"join",code:room.code}));assert.equal((await joined).slot,i+1);await peer;
 }
 wait=once(outsider,"error");outsider.send(JSON.stringify({type:"join",code:room.code}));await wait;
 for(let i=0;i<3;i++){
   wait=once(host,"input");guests[i].send(JSON.stringify({type:"input",sender:0,seq:1,data:{move_right:true}}));
   const input=await wait;assert.equal(input.sender,i+1);assert.equal(input.data.move_right,true);
 }
 let all=Promise.all(guests.map(g=>once(g,"start")));host.send(JSON.stringify({type:"start",config:{boss:"central"}}));
 for(const packet of await all)assert.equal(packet.config.boss,"central");
 all=Promise.all(guests.map(g=>once(g,"snapshot")));host.send(JSON.stringify({type:"snapshot",data:{frame:7}}));
 for(const packet of await all)assert.equal(packet.data.frame,7);
 wait=once(host,"peer_left");guests[2].close();assert.equal((await wait).slot,3);
 wait=once(outsider,"error");outsider.send(JSON.stringify({type:"join",code:room.code}));await wait;
 all=Promise.all(guests.slice(0,2).map(g=>once(g,"host_left")));host.close();await all;
 outsider.close();await new Promise(r=>setTimeout(r,80));assert.equal(relay.rooms.size,0);
 console.log("RELAY: four slots, fifth rejected, sender cannot be spoofed, broadcasts, mid-match join denied, disconnect cleanup passed");
 relay.close();
})().catch(error=>{console.error(error);relay.close();process.exitCode=1;});
