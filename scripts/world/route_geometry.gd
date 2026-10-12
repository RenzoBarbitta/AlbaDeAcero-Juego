extends RefCounted
## Quantized risers: shallow diagonals become terraces, not decks a few pixels apart.
static func points(anchors: Array,max_x: float = 72) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(anchors.size()-1):
		var a: Vector2 = anchors[i]
		var b: Vector2 = anchors[i+1]
		var rises := ceili(absf(b.y-a.y)/40)
		var hops := maxi(1,maxi(ceili(absf(b.x-a.x)/max_x),rises))
		# A near-vertical descent is an open drop, not a stack of overlapping stairs.
		if b.y-a.y>120 and absf(b.x-a.x)<160:
			result.append(a)
			continue
		for j in hops:
			var fraction := float(j)/hops
			var y := a.y
			if rises>0:
				y += signf(b.y-a.y)*floorf(fraction*rises)*absf(b.y-a.y)/rises
			result.append(Vector2(lerpf(a.x,b.x,fraction),y))
	result.append(anchors.back())
	return result
