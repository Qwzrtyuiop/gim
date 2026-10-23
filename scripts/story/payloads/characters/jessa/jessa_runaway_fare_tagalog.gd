extends RefCounted

const JessaEvent := preload("res://scripts/story/payloads/characters/jessa/jessa_runaway_fare.gd")

# Same sections and branch actions as English; only the dialogue is localized.
const TEXT: Array[String] = [
	"Itinigil ko ang tricycle sa destinasyon ng aking pasahero.",
	"Nandito na tayo.",
	"Ah, okay. Salamat po.",
	"Yung bayad mo.",
	"Sige po, sandali lang...",
	"Dinukot ng babae ang maliit niyang pitaka mula sa bulsa.",
	"Tingnan ko lang...",
	"Ay...",
	"Hm?",
	"...",
	"KUYA! SA LIKOD MO! ANO 'YON?!",
	"Bigla niyang itinuro ang kung ano sa likuran ko.",
	"Ha? Ano?",
	"Lumingon ako, pero wala naman akong nakita.",
	"Ano—",
	"Nang ako'y lumingon pabalik, tumatakbo na papalayo ang babae.",
	"HOY!",
	"HOY! BUMALIK KA DITO!",
	"Mabilis akong bumaba ng tricycle at hinabol siya.",
	"HINDI KA PA NAGBABAYAD!",
	"SORRY, KUYA!",
	"Lumiko ang babae sa isang makitid na eskinita. Pagdating ko roon, hindi ko na siya makita.",
	"Hah... Hah...",
	"Anak ng...",
	"Matapos mawala ang aking hingal, naglakad ako pabalik sa tricycle. Nakakaramdam ako na hindi pa ito ang huli naming pagkikita.",
	"Pinanood ko na lang siyang tumakbo hanggang sa mawala siya sa kanto.",
	"...",
	"Haaah...",
	"Napabuntong-hininga ako bago bumalik sa tricycle.",
	"Sayang ang pamasahe...",
	"Sumakay ulit ako at nagpatuloy sa biyahe. Nakakaramdam ako na hindi pa ito ang huli naming pagkikita.",
]


static func build() -> Dictionary:
	var payload := JessaEvent.build()
	var composition: Array = payload["composition"]
	assert(composition.size() == TEXT.size(), "Jessa's translations must match the shared story sections.")
	for index in range(composition.size()):
		composition[index]["text"] = TEXT[index]
		# This script requests payment without quoting an amount.
		composition[index].erase("ride_fare_line")
		if composition[index].has("choices"):
			composition[index]["choices"][0]["text"] = "Habulin siya."
			composition[index]["choices"][1]["text"] = "Hayaan na siya."
	return payload
