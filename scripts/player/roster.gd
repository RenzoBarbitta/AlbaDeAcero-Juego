extends RefCounted
const ORDER := ["orange","red","black","violet","mint","white","gold","cyan"]
const DATA := {
	"orange":{"name":"AXEL","epithet":"EXPLORADOR","primary":"buster","alt":"spread","color":Color("ff8b39"),"speed":1.08,"desc":"CANON CARGADO. MOVILIDAD EQUILIBRADA."},
	"red":{"name":"BASTION","epithet":"VANGUARDIA","primary":"spread","alt":"laser","color":Color("ee554e"),"speed":0.92,"desc":"ESCOPETA. BLINDAJE REDUCE EL DANO RECIBIDO."},
	"black":{"name":"NIX","epithet":"INFILTRACION","primary":"laser","alt":"plasma","color":Color("9a9ed5"),"speed":1.2,"desc":"RIFLE PERFORANTE. EL PILOTO MAS VELOZ."},
	"violet":{"name":"ORION","epithet":"GRAVITACION","primary":"plasma","alt":"buster","color":Color("b27bff"),"speed":1.0,"desc":"ORBE DE PLASMA PESADO Y PENETRANTE."},
	"mint":{"name":"IRIS","epithet":"RESCATE","primary":"needles","alt":"buster","color":Color("70f0ba"),"speed":1.1,"desc":"AGUJAS GEMELAS. RESCATA AL DOBLE DE VELOCIDAD."},
	"white":{"name":"TORQUE","epithet":"DEMOLICION","primary":"grenade","alt":"spread","color":Color("f3d5a5"),"speed":0.95,"desc":"LANZAGRANADAS BALISTICO CON EXPLOSION."},
	"gold":{"name":"AEGIS","epithet":"GUARDIAN","primary":"rail","alt":"laser","color":Color("ffd567"),"speed":1.0,"desc":"ARCO DE RIEL. ATRAVIESA FILAS DE ENEMIGOS."},
	"cyan":{"name":"NOVA","epithet":"COMANDANTE","primary":"drones","alt":"plasma","color":Color("68deff"),"speed":1.12,"desc":"TRES MICRODRONES BUSCAN OBJETIVOS."}
}
const WEAPONS := {"buster":"PULSO","spread":"ESCOPETA","laser":"RIFLE","plasma":"PLASMA","needles":"AGUJAS","grenade":"GRANADAS","rail":"ARCO RIEL","drones":"MICRODRONES"}
