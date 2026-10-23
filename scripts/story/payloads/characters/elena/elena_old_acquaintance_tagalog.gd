extends RefCounted

const ElenaEvent := preload("res://scripts/story/payloads/characters/elena/elena_old_acquaintance.gd")


static func build() -> Dictionary:
	return ElenaEvent.build_scene([
		{"text": "Habang bumibiyahe ako sa dati kong ruta, biglang nagsalita ang matandang babae na nakasakay sa tricycle ko."},
		{"speaker": "Elena", "text": "Excuse me, iho."},
		{"speaker": "John Toda", "text": "Po?"},
		{"speaker": "Elena", "text": "Ikaw ba 'yan, John?"},
		{"speaker": "John Toda", "text": "Ha?"},
		{"speaker": "Elena", "text": "John Toda, tama ba?"},
		{"speaker": "John Toda", "text": "Ah... Opo. Magkakilala po ba tayo?"},
		{"speaker": "Elena", "text": "Ay, ikaw nga! Naku, ang laki mo na!"},
		{"speaker": "John Toda", "text": "Pasensya na po, pero..."},
		{"speaker": "Elena", "text": "Ay, oo nga pala. Ako si Elena. Dati akong guro rito.", "introduces_speaker": true},
		{"speaker": "John Toda", "text": "Ah..."},
		{"speaker": "Elena", "text": "Kilala ko ang tatay mo, si Juan. Ang tagal na rin mula noong huli ko siyang nakita."},
		{"speaker": "John Toda", "text": "Gano'n po ba."},
		{"speaker": "Elena", "text": "Kumusta na pala siya ngayon? Mabuti naman ba ang lagay niya?"},
	], [
		{"speaker": "John Toda", "text": "Patay na po siya."},
		{"speaker": "Elena", "text": "Ay..."},
		{"speaker": "Elena", "text": "Hindi... Hindi ko alam. Pasensya ka na, iho."},
		{"speaker": "John Toda", "text": "Ayos lang po."},
		{"speaker": "Elena", "text": "Kung pwede ko lang itanong, kailan pa siya..."},
		{"speaker": "John Toda", "text": "Matagal na rin po."},
		{"speaker": "Elena", "text": "Gano'n ba..."},
		{"text": "Tahimik na lumipas ang natitirang biyahe."},
		{"speaker": "Elena", "text": "Ay, dito na pala ako."},
		{"speaker": "John Toda", "text": "Sige po."},
		{"speaker": "Elena", "text": "Salamat sa paghatid, John."},
		{"speaker": "John Toda", "text": "Walang anuman po."},
		{"text": "Nagbayad siya ng pamasahe at bumaba ng tricycle."},
	], [
		{"speaker": "John Toda", "text": "Hindi ko po alam."},
		{"speaker": "Elena", "text": "Ay, bakit naman?"},
		{"speaker": "John Toda", "text": "Matagal ko na rin po kasi siyang hindi nakikita."},
		{"speaker": "Elena", "text": "Ah, gano'n ba..."},
		{"speaker": "Elena", "text": "Sana naman ay nasa mabuti siyang kalagayan."},
		{"speaker": "John Toda", "text": "Opo."},
		{"text": "Doon na natapos ang usapan namin at nagpatuloy ako sa pagmamaneho."},
		{"speaker": "Elena", "text": "Ay, dito na pala ako."},
		{"speaker": "John Toda", "text": "Sige po."},
		{"speaker": "Elena", "text": "Salamat sa paghatid, John."},
		{"speaker": "John Toda", "text": "Walang anuman po."},
		{"text": "Nagbayad siya ng pamasahe at bumaba ng tricycle."},
	], "Sabihin ang totoo", "Magsinungaling")
