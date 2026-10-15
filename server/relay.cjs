const http = require("node:http");
const crypto = require("node:crypto");
const {WebSocketServer, WebSocket} = require("ws");
function createRelay(port=Number(process.env.PORT||8787),address="0.0.0.0") {
  const rooms = new Map();
  const server = http.createServer((req,res)=>{res.writeHead(200,{"content-type":"application/json"});res.end(JSON.stringify({service:"alba-room-relay",rooms:rooms.size}));});
  const wss = new WebSocketServer({server,maxPayload:512*1024});
  // World states become obsolete every 50 ms; do not queue seconds of stale state.
  const send=(socket,message)=>{if(socket?.readyState===WebSocket.OPEN && (message.type!=="snapshot" || socket.bufferedAmount<32*1024))socket.send(JSON.stringify(message));};
  wss.on("connection",socket=>{
    let room=null, role="", slot=-1, attempts=0, window=Date.now();
    socket.on("message",raw=>{
      let msg;try{msg=JSON.parse(raw.toString());}catch{return send(socket,{type:"error",message:"Mensaje invalido"});}
      if (!msg || typeof msg.type!=="string")return;
      if(msg.type==="create"||msg.type==="join"){
        if(Date.now()-window>60000){attempts=0;window=Date.now();}
        if(++attempts>12)return send(socket,{type:"error",message:"Demasiados intentos"});
        if(room)return send(socket,{type:"error",message:"Ya estas en una sala"});
        if(msg.type==="create"){
          let code;do{code=crypto.randomBytes(4).toString("hex").slice(0,6).toUpperCase();}while(rooms.has(code));
          room={code,host:socket,peers:new Map([[0,socket]]),started:false,created:Date.now()};role="host";slot=0;rooms.set(code,room);
          send(socket,{type:"created",code,role,slot,slots:[0]});
        }else{
          const candidate=rooms.get(String(msg.code||"").toUpperCase());
          if(!candidate||candidate.peers.size>=4||candidate.started)return send(socket,{type:"error",message:"Sala inexistente o completa"});
          room=candidate;role="guest";slot=[1,2,3].find(i=>!room.peers.has(i));room.peers.set(slot,socket);
          send(socket,{type:"joined",code:room.code,role,slot,slots:[...room.peers.keys()]});
          for(const peer of room.peers.values())send(peer,{type:"peer_joined",slot,slots:[...room.peers.keys()]});
        }
        return;
      }
      if(!room)return send(socket,{type:"error",message:"Primero crea o entra a una sala"});
      if(role==="guest"&&["input","profile","control"].includes(msg.type))send(room.host,{...msg,sender:slot});
      if(role==="host"&&["start","snapshot","lobby","roster"].includes(msg.type)){
        if(msg.type==="start")room.started=true;
        if(msg.type==="lobby")room.started=false;
        for(const [id,peer] of room.peers)if(id!==0)send(peer,msg);
      }
    });
    socket.on("close",()=>{
      if(!room)return;
      if(role==="host"){rooms.delete(room.code);for(const [id,peer] of room.peers)if(id!==0){send(peer,{type:"host_left"});peer.close();}}
      else {room.peers.delete(slot);for(const peer of room.peers.values())send(peer,{type:"peer_left",slot,slots:[...room.peers.keys()]});}
    });
    socket.on("error",()=>{});
  });
  const timer=setInterval(()=>{
    for(const [code,room] of rooms)if(room.peers.size===1&&Date.now()-room.created>1800000){room.host.close();rooms.delete(code);}
  },60000);timer.unref();
  server.listen(port,address);
  return {server,wss,rooms,close:()=>{clearInterval(timer);for(const s of wss.clients)s.terminate();wss.close();server.close();}};
}
if(require.main===module){const relay=createRelay();relay.server.on("listening",()=>process.stdout.write("Room relay listening on "+relay.server.address().port+"; PID "+process.pid+"\n"));}
module.exports={createRelay};
