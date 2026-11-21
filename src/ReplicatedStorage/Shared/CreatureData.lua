-- CreatureData: all 54 creatures.
-- Location: ReplicatedStorage > Shared > CreatureData (ModuleScript)
--
-- Field reference (all used by CreatureBuilder / CreatureAnimator):
--   body  : round | quad | bird | slime | ghost | fish | dragon | bug | golem
--   move  : hop | walk | fly | float | slither
--   idle  : bounce | sway | spin | wiggle | proud | float | peek | dance
--   c     : { primary, secondary, accent } hex colours
--   ears  : none | round | pointy | bunny | floppy | cat | fin
--   horns : none | small | ram | antlers | unicorn | dragon
--   tail  : none | fluffy | flame | long | lollipop | fish | stinger | leaf | aurora
--   wings : none | feather | bat | bug | angel
--   extra : list of none | acorn | flower | leafsprout | crown | halo | helmet | crystal |
--           mane | spikes | antenna | shell | candy | rings | eyepatch | bow | snowcap | scarf
--   eyes  : big | sleepy | fierce | sparkle | cyclops | glow
--   mat   : material of the main body (default SmoothPlastic)
--   fx    : particle style for rare creatures
--   scale : extra size multiplier (on top of rarity size)
--   world : world id, or "Any" (portal-exclusive Secret/Divine creatures)

local L = {}
local function add(t) table.insert(L, t) end

---------------------------------------------------------------- GREEN FOREST
add{ id="Mossbun", name="Mossbun", rarity="Common", world="Forest", body="round", move="hop", idle="bounce",
	c={"#8BD86A","#F4FFE6","#4E9C3A"}, ears="bunny", tail="fluffy", eyes="big", extra={"leafsprout"},
	desc="A fluffy bunny that grows moss when it naps." }
add{ id="Acornip", name="Acornip", rarity="Uncommon", world="Forest", body="quad", move="walk", idle="peek",
	c={"#B9773F","#F6D9B0","#6B3F1C"}, ears="round", tail="fluffy", eyes="big", extra={"acorn"}, scale=0.9,
	desc="Wears its favourite acorn as a hat. Never takes it off." }
add{ id="Petalfly", name="Petalfly", rarity="Rare", world="Forest", body="bug", move="fly", idle="float",
	c={"#FF9AD5","#FFF3A6","#7A3BD1"}, wings="bug", eyes="sparkle", extra={"antenna"}, fx="sparkle",
	desc="Its wings are made of real flower petals." }
add{ id="Thornhog", name="Thornhog", rarity="Epic", world="Forest", body="quad", move="walk", idle="wiggle",
	c={"#C99B6D","#FFE9CF","#3FAA4A"}, ears="round", eyes="big", extra={"spikes","flower"}, fx="leaves",
	desc="Its spikes are soft leaves... mostly." }
add{ id="Elderstag", name="Elderstag Sprite", rarity="Legendary", world="Forest", body="quad", move="walk", idle="proud",
	c={"#EDE3C8","#FFFFFF","#7CFFB0"}, ears="pointy", horns="antlers", tail="fluffy", eyes="glow", fx="leaves", scale=1.1,
	desc="Ancient guardian of the forest. Its antlers glow at dusk." }
add{ id="Bloomwyrm", name="Bloomwyrm", rarity="Mythical", world="Forest", body="dragon", move="fly", idle="sway",
	c={"#5ED67A","#FFD6F0","#FF5FA8"}, horns="dragon", tail="leaf", wings="bat", eyes="fierce", extra={"flower"}, fx="sparkle",
	desc="A dragon that blooms a new flower with every breath." }

---------------------------------------------------------------- VOLCANO WORLD
add{ id="Emberpup", name="Emberpup", rarity="Common", world="Volcano", body="quad", move="walk", idle="wiggle",
	c={"#FF7A3D","#FFE0B8","#FFD13B"}, ears="pointy", tail="flame", eyes="big", fx="embers",
	desc="Wags its burning tail when happy. Keep away from curtains." }
add{ id="Magmite", name="Magmite", rarity="Uncommon", world="Volcano", body="slime", move="hop", idle="bounce",
	c={"#FF5A1F","#FFD04A","#3A1A10"}, eyes="big", mat="Neon", fx="embers",
	desc="A warm, gooey blob of living lava." }
add{ id="Cinderchick", name="Cinderchick", rarity="Rare", world="Volcano", body="bird", move="hop", idle="peek",
	c={"#FFB23B","#FFF0C2","#FF4A1A"}, wings="feather", tail="flame", eyes="big", extra={"leafsprout"}, fx="embers",
	desc="Its first chirp sparks a tiny campfire." }
add{ id="Obsidigolem", name="Obsidian Golem", rarity="Epic", world="Volcano", body="golem", move="walk", idle="proud",
	c={"#2A2230","#FF6A2A","#FFB14A"}, eyes="glow", extra={"crystal"}, mat="Slate", fx="embers", scale=1.1,
	desc="Lava flows through the cracks in its stone skin." }
add{ id="PhoenixLumen", name="Phoenix Lumen", rarity="Legendary", world="Volcano", body="bird", move="fly", idle="float",
	c={"#FF6B1A","#FFE45C","#FF2A6D"}, wings="feather", tail="flame", eyes="glow", extra={"crown"}, fx="fire", scale=1.1,
	desc="Reborn from its own ashes every sunrise." }
add{ id="Infernadrake", name="Infernadrake", rarity="Mythical", world="Volcano", body="dragon", move="fly", idle="proud",
	c={"#B3201A","#FFB347","#FFE14A"}, horns="dragon", tail="flame", wings="bat", eyes="fierce", extra={"spikes"}, fx="fire",
	desc="King of the volcano. Its roar melts rock." }

---------------------------------------------------------------- FROZEN KINGDOM
add{ id="Frostpaw", name="Frostpaw", rarity="Common", world="Frozen", body="round", move="hop", idle="wiggle",
	c={"#DDF3FF","#FFFFFF","#7EC8FF"}, ears="cat", tail="fluffy", eyes="big", extra={"scarf"},
	desc="Knits its own scarves. Very proud of them." }
add{ id="Snowpuff", name="Snowpuff", rarity="Uncommon", world="Frozen", body="round", move="hop", idle="bounce",
	c={"#FFFFFF","#E3F4FF","#9AD7FF"}, ears="round", eyes="sleepy", extra={"snowcap"}, fx="snow", scale=0.85,
	desc="A sleepy snowball that rolls everywhere." }
add{ id="IcicleOwl", name="Icicle Owl", rarity="Rare", world="Frozen", body="bird", move="fly", idle="peek",
	c={"#BFE6FF","#FFFFFF","#3B8BD6"}, ears="pointy", wings="feather", eyes="big", fx="snow",
	desc="Can turn its head all the way around. Showoff." }
add{ id="GlacierYeti", name="Glacier Yeti", rarity="Epic", world="Frozen", body="golem", move="walk", idle="dance",
	c={"#F4FBFF","#9AD9FF","#2D6FB0"}, horns="ram", eyes="big", mat="SmoothPlastic", fx="snow", scale=1.1,
	desc="Huge, fluffy, and loves to dance in blizzards." }
add{ id="AuroraFox", name="Aurora Fox", rarity="Legendary", world="Frozen", body="quad", move="walk", idle="sway",
	c={"#E8F7FF","#FFFFFF","#7CFFCB"}, ears="pointy", tail="aurora", eyes="glow", fx="sparkle",
	desc="Its tail paints the northern lights across the sky." }
add{ id="Crystalwing", name="Crystalwing Dragon", rarity="Mythical", world="Frozen", body="dragon", move="fly", idle="float",
	c={"#A6E4FF","#FFFFFF","#4AB8FF"}, horns="dragon", tail="long", wings="angel", eyes="glow", extra={"crystal"}, mat="Glass", fx="snow",
	desc="Every beat of its wings creates a snowflake." }

---------------------------------------------------------------- CRYSTAL CAVES
add{ id="Gemmy", name="Gemmy", rarity="Common", world="Crystal", body="slime", move="hop", idle="bounce",
	c={"#B07CFF","#E9D9FF","#5A2BA8"}, eyes="big", mat="Glass", extra={"crystal"},
	desc="A jelly with a tiny gem floating inside." }
add{ id="QuartzBeetle", name="Quartz Beetle", rarity="Uncommon", world="Crystal", body="bug", move="walk", idle="wiggle",
	c={"#E2E8F0","#9FE7FF","#3C4A6B"}, eyes="big", extra={"shell","antenna"}, mat="Glass",
	desc="Its shell sparkles like a disco ball." }
add{ id="GlimmerBat", name="Glimmer Bat", rarity="Rare", world="Crystal", body="round", move="fly", idle="float",
	c={"#5B3B8C","#FFC6F5","#C68BFF"}, ears="pointy", wings="bat", eyes="sparkle", fx="sparkle", scale=0.9,
	desc="Hangs upside down to watch the crystals glow." }
add{ id="AmethystEel", name="Amethyst Eel", rarity="Epic", world="Crystal", body="fish", move="slither", idle="sway",
	c={"#9B4DFF","#F2D6FF","#FF7AE6"}, ears="fin", tail="fish", eyes="glow", extra={"crystal"}, fx="sparkle",
	desc="Swims through solid rock like it's water." }
add{ id="PrismLion", name="Prism Lion", rarity="Legendary", world="Crystal", body="quad", move="walk", idle="proud",
	c={"#F6E7FF","#FFFFFF","#B66BFF"}, ears="round", tail="long", eyes="glow", extra={"mane","crystal"}, mat="SmoothPlastic", fx="rainbow", scale=1.1,
	desc="Its crystal mane splits light into rainbows." }
add{ id="GeodeLeviathan", name="Geode Leviathan", rarity="Mythical", world="Crystal", body="dragon", move="fly", idle="sway",
	c={"#3B2466","#FF8BF0","#7DF9FF"}, horns="dragon", tail="long", wings="bat", eyes="glow", extra={"crystal","spikes"}, fx="stars",
	desc="Sleeps for a thousand years inside a giant geode." }

---------------------------------------------------------------- CANDY WORLD
add{ id="Gumdrop", name="Gumdrop", rarity="Common", world="Candy", body="slime", move="hop", idle="bounce",
	c={"#FF5FA2","#FFD1E6","#FFFFFF"}, eyes="big", mat="Glass", extra={"candy"},
	desc="Covered in sugar crystals. Smells like strawberries." }
add{ id="CocoaCub", name="Cocoa Cub", rarity="Uncommon", world="Candy", body="round", move="walk", idle="dance",
	c={"#8A5232","#F2C8A0","#FF6FB1"}, ears="round", tail="none", eyes="big", extra={"bow"},
	desc="A chocolate bear who never melts... unless hugged too long." }
add{ id="Lollipup", name="Lollipup", rarity="Rare", world="Candy", body="quad", move="walk", idle="wiggle",
	c={"#FFF0F6","#FF5FA2","#5FD3FF"}, ears="floppy", tail="lollipop", eyes="big", extra={"bow"}, fx="hearts",
	desc="Its tail is a swirly lollipop. Do not lick." }
add{ id="Marshghost", name="Marshmallow Ghost", rarity="Epic", world="Candy", body="ghost", move="float", idle="float",
	c={"#FFFFFF","#FFE1F0","#FF9AC8"}, eyes="sleepy", fx="hearts",
	desc="The softest ghost in existence. Boo... please?" }
add{ id="Sugarcorn", name="Sugarcorn", rarity="Legendary", world="Candy", body="quad", move="walk", idle="proud",
	c={"#FFE3F2","#FFFFFF","#FF5FD0"}, ears="pointy", horns="unicorn", tail="aurora", eyes="sparkle", extra={"mane"}, fx="rainbow", scale=1.1,
	desc="Its horn is a candy cane that grants sweet wishes." }
add{ id="QueenBee", name="Candy Queen Bee", rarity="Mythical", world="Candy", body="bug", move="fly", idle="dance",
	c={"#FFD23B","#2A1A10","#FF6FB1"}, wings="bug", tail="stinger", eyes="sparkle", extra={"crown","antenna"}, fx="sparkle", scale=1.2,
	desc="Rules the honey-candy hives with a sticky fist." }

---------------------------------------------------------------- SPACE GALAXY
add{ id="AstroBlob", name="Astro Blob", rarity="Common", world="Space", body="slime", move="hop", idle="bounce",
	c={"#7CF2C8","#E6FFF6","#2B6B5A"}, eyes="big", extra={"helmet","antenna"},
	desc="An alien who wears a fishbowl for protection." }
add{ id="MoonMouse", name="Moon Mouse", rarity="Uncommon", world="Space", body="round", move="hop", idle="peek",
	c={"#C9CCE0","#FFFFFF","#FF9AC8"}, ears="round", tail="long", eyes="big", extra={"helmet"},
	desc="Convinced the moon is made of cheese. Still searching." }
add{ id="CometFish", name="Comet Fish", rarity="Rare", world="Space", body="fish", move="float", idle="sway",
	c={"#5BC0FF","#FFFFFF","#FFE45C"}, ears="fin", tail="flame", eyes="big", fx="stars",
	desc="Swims between stars, leaving a glittering trail." }
add{ id="NebulaJelly", name="Nebula Jelly", rarity="Epic", world="Space", body="ghost", move="float", idle="float",
	c={"#B06BFF","#FF8AE2","#5BE3FF"}, eyes="sparkle", mat="Glass", extra={"antenna"}, fx="stars",
	desc="A whole nebula swirls inside its glassy body." }
add{ id="StarWhale", name="Star Whale", rarity="Legendary", world="Space", body="fish", move="float", idle="sway",
	c={"#2B3B8C","#9FD3FF","#FFE45C"}, ears="fin", tail="fish", eyes="glow", extra={"rings"}, fx="stars", scale=1.5,
	desc="Sings songs that make new stars appear." }
add{ id="CosmicDragon", name="Cosmic Dragon", rarity="Mythical", world="Space", body="dragon", move="fly", idle="spin",
	c={"#1A1040","#7A5BFF","#FF5FD0"}, horns="dragon", tail="long", wings="bat", eyes="glow", extra={"rings"}, mat="Glass", fx="stars",
	desc="Made of stardust. Its scales are tiny galaxies." }

---------------------------------------------------------------- SHADOW DIMENSION
add{ id="Gloomling", name="Gloomling", rarity="Common", world="Shadow", body="ghost", move="float", idle="peek",
	c={"#3B2A55","#7A5BAA","#B78CFF"}, eyes="big", fx="smoke", scale=0.85,
	desc="Shy little shadow. Hides behind your legs." }
add{ id="ShadeCat", name="Shade Cat", rarity="Uncommon", world="Shadow", body="quad", move="walk", idle="sway",
	c={"#251A33","#5A3F7A","#C7FF5C"}, ears="cat", tail="long", eyes="glow",
	desc="Only its glowing eyes are visible at night." }
add{ id="NightMoth", name="Night Moth", rarity="Rare", world="Shadow", body="bug", move="fly", idle="float",
	c={"#4A3A6B","#D9C7FF","#8AF0FF"}, wings="bug", eyes="sparkle", extra={"antenna"}, fx="sparkle",
	desc="Attracted to the glow of portals." }
add{ id="VoidWisp", name="Void Wisp", rarity="Epic", world="Shadow", body="ghost", move="float", idle="spin",
	c={"#120A1E","#8A2BFF","#FF3BD4"}, eyes="cyclops", mat="Neon", fx="smoke",
	desc="A flicker of pure darkness with one curious eye." }
add{ id="UmbraWolf", name="Umbra Wolf", rarity="Legendary", world="Shadow", body="quad", move="walk", idle="proud",
	c={"#1E1630","#4B3570","#B44BFF"}, ears="pointy", tail="fluffy", eyes="fierce", extra={"spikes"}, fx="smoke", scale=1.15,
	desc="Howls at a moon that doesn't exist." }
add{ id="NightmareWyvern", name="Nightmare Wyvern", rarity="Mythical", world="Shadow", body="dragon", move="fly", idle="sway",
	c={"#0F0A18","#5A1A8C","#FF2A4D"}, horns="ram", tail="stinger", wings="bat", eyes="fierce", extra={"spikes"}, fx="smoke",
	desc="Born from the worst dream of a sleeping god." }

---------------------------------------------------------------- HEAVEN WORLD
add{ id="CloudLamb", name="Cloud Lamb", rarity="Common", world="Heaven", body="round", move="hop", idle="bounce",
	c={"#FFFFFF","#FFF4D6","#FFC8DD"}, ears="floppy", horns="ram", eyes="sleepy", extra={"mane"},
	desc="Its wool is a real cloud. It sometimes rains." }
add{ id="HaloChick", name="Halo Chick", rarity="Uncommon", world="Heaven", body="bird", move="hop", idle="peek",
	c={"#FFF6C2","#FFFFFF","#FFC94A"}, wings="angel", eyes="big", extra={"halo"}, fx="holy",
	desc="Took a halo from the lost & found. Kept it." }
add{ id="Seraphling", name="Seraphling", rarity="Rare", world="Heaven", body="round", move="fly", idle="float",
	c={"#FFEFD6","#FFFFFF","#FFD86B"}, ears="none", wings="angel", eyes="sparkle", extra={"halo"}, fx="holy",
	desc="A tiny angel in training. Still learning to fly straight." }
add{ id="GoldGriffin", name="Golden Griffin", rarity="Epic", world="Heaven", body="bird", move="fly", idle="proud",
	c={"#FFD24A","#FFF6D6","#C9881A"}, ears="pointy", wings="feather", tail="fluffy", eyes="fierce", extra={"crown"}, mat="Metal", fx="holy", scale=1.2,
	desc="Guards the golden gates. Accepts bribes in cookies." }
add{ id="Pegasus", name="Celestial Pegasus", rarity="Legendary", world="Heaven", body="quad", move="fly", idle="proud",
	c={"#FFFFFF","#E8F4FF","#FFD86B"}, ears="pointy", tail="aurora", wings="angel", eyes="sparkle", extra={"mane","halo"}, fx="holy", scale=1.15,
	desc="Gallops across rainbows at the speed of light." }
add{ id="ArchDrake", name="Archangel Drake", rarity="Mythical", world="Heaven", body="dragon", move="fly", idle="float",
	c={"#FFF8E6","#FFFFFF","#FFC23B"}, horns="unicorn", tail="long", wings="angel", eyes="glow", extra={"halo","crown"}, fx="holy",
	desc="The guardian dragon of Heaven's highest tower." }

---------------------------------------------------------------- SECRET (portal-exclusive, any world)
add{ id="Glitchling", name="Glitchling", rarity="Secret", world="Any", body="round", move="hop", idle="spin",
	c={"#00FFC8","#FF00AA","#000000"}, ears="cat", eyes="cyclops", mat="Neon", fx="glitch",
	desc="ERR0R: creature.exe has stopped responding." }
add{ id="VoidEmperor", name="Void Emperor", rarity="Secret", world="Any", body="golem", move="walk", idle="proud",
	c={"#05040A","#3D0066","#00FFD0"}, horns="ram", eyes="glow", extra={"crown","crystal"}, fx="glitch",
	desc="Ruler of the space between portals." }
add{ id="Errorcat", name="Error Cat", rarity="Secret", world="Any", body="quad", move="walk", idle="dance",
	c={"#FF00FF","#000000","#00FF66"}, ears="cat", tail="long", eyes="big", extra={"eyepatch"}, mat="Neon", fx="glitch",
	desc="It's here. It's there. It's... everywhere?" }

---------------------------------------------------------------- DIVINE (portal-exclusive, any world)
add{ id="Solaris", name="Solaris", rarity="Divine", world="Any", body="round", move="float", idle="spin",
	c={"#FFE14A","#FFFFFF","#FF9A1A"}, eyes="glow", extra={"halo","crown"}, mat="Neon", fx="holy",
	desc="A baby sun. Very warm hugs." }
add{ id="Aetherion", name="Aetherion", rarity="Divine", world="Any", body="dragon", move="fly", idle="proud",
	c={"#FFFFFF","#BFF6FF","#FFD24A"}, horns="dragon", tail="aurora", wings="angel", eyes="glow", extra={"halo","crown","crystal"}, fx="holy",
	desc="The first creature to ever step through a portal." }
add{ id="EternityOwl", name="Eternity Owl", rarity="Divine", world="Any", body="bird", move="fly", idle="float",
	c={"#2A1A5E","#FFE9A6","#7DF9FF"}, ears="pointy", wings="angel", tail="aurora", eyes="glow", extra={"halo","rings"}, fx="stars",
	desc="Has watched every moment of time. Remembers your birthday." }

---------------------------------------------------------------- EXTRA RARES (one more Legendary + Mythical per world)
add{ id="OakTitan", name="Oak Titan", rarity="Legendary", world="Forest", body="golem", move="walk", idle="proud",
	c={"#7A5A3A","#9BE07A","#FFE36B"}, horns="antlers", eyes="glow", extra={"leafsprout","flower"}, mat="Wood", fx="leaves", scale=1.05,
	desc="A walking tree older than the forest itself." }
add{ id="SylphQueen", name="Sylph Queen", rarity="Mythical", world="Forest", body="bug", move="fly", idle="dance",
	c={"#C8FFB0","#FFFFFF","#FF8AD8"}, wings="bug", eyes="sparkle", extra={"crown","antenna","flower"}, fx="sparkle", scale=1.25,
	desc="Every flower in the forest bows when she flies by." }
add{ id="MagmaKraken", name="Magma Kraken", rarity="Legendary", world="Volcano", body="fish", move="float", idle="sway",
	c={"#FF4A1A","#FFC24A","#2A0A05"}, ears="fin", tail="flame", eyes="fierce", extra={"spikes"}, mat="Neon", fx="fire", scale=1.3,
	desc="Swims through rivers of lava like they're bathwater." }
add{ id="SolarSerpent", name="Solar Serpent", rarity="Mythical", world="Volcano", body="dragon", move="fly", idle="spin",
	c={"#FFD23B","#FF7A1A","#FFFFFF"}, horns="unicorn", tail="flame", wings="angel", eyes="glow", extra={"halo","crystal"}, fx="fire",
	desc="Its scales are tiny suns. Bring sunglasses." }
add{ id="BlizzardBear", name="Blizzard Bear", rarity="Legendary", world="Frozen", body="round", move="walk", idle="proud",
	c={"#FFFFFF","#C9EEFF","#3BA8FF"}, ears="round", eyes="fierce", extra={"crown","snowcap"}, fx="snow", scale=1.35,
	desc="Its roar starts avalanches three mountains away." }
add{ id="FrostEmpress", name="Frost Empress", rarity="Mythical", world="Frozen", body="bird", move="fly", idle="float",
	c={"#E6F8FF","#FFFFFF","#7FE0FF"}, ears="pointy", wings="angel", tail="aurora", eyes="glow", extra={"crown","crystal"}, mat="Glass", fx="snow", scale=1.25,
	desc="Rules the north from a palace made of a single snowflake." }
add{ id="DiamondDrake", name="Diamond Drake", rarity="Legendary", world="Crystal", body="dragon", move="fly", idle="proud",
	c={"#E8F4FF","#FFFFFF","#7DF9FF"}, horns="dragon", tail="long", wings="bat", eyes="glow", extra={"crystal","spikes"}, mat="Glass", fx="rainbow",
	desc="Sparkles so hard it can be seen from space." }
add{ id="VoidCrystalHydra", name="Prismatic Hydra", rarity="Mythical", world="Crystal", body="dragon", move="walk", idle="sway",
	c={"#B06BFF","#FF8BF0","#7DF9FF"}, horns="ram", tail="long", wings="angel", eyes="sparkle", extra={"crystal","crown","rings"}, mat="Glass", fx="rainbow", scale=1.15,
	desc="Each of its crystals hums a different musical note." }
add{ id="CottonCandyCloud", name="Cotton Candy Kirin", rarity="Legendary", world="Candy", body="quad", move="float", idle="dance",
	c={"#FFC2E6","#C2E9FF","#FFFFFF"}, ears="pointy", horns="unicorn", tail="aurora", eyes="sparkle", extra={"mane","candy"}, fx="hearts", scale=1.1,
	desc="Made entirely of spun sugar and good vibes." }
add{ id="ChocoTitan", name="Chocolate Colossus", rarity="Mythical", world="Candy", body="golem", move="walk", idle="dance",
	c={"#6B3A1E","#FFB6D9","#FF5FA2"}, horns="small", eyes="big", extra={"crown","candy","bow"}, fx="hearts", scale=1.2,
	desc="Gives the best hugs. Leaves chocolate stains." }
add{ id="NovaPhoenix", name="Nova Phoenix", rarity="Legendary", world="Space", body="bird", move="fly", idle="spin",
	c={"#2A1A6E","#FF8AE2","#5BE3FF"}, wings="feather", tail="aurora", eyes="glow", extra={"rings","crown"}, mat="Glass", fx="stars", scale=1.15,
	desc="Explodes into a supernova and reforms every century." }
add{ id="Singularity", name="Singularity Cat", rarity="Mythical", world="Space", body="quad", move="float", idle="peek",
	c={"#05050F","#7A5BFF","#FFFFFF"}, ears="cat", tail="long", eyes="cyclops", extra={"rings","halo"}, mat="Neon", fx="stars",
	desc="A tiny black hole that purrs. Do not pet the event horizon." }
add{ id="Wraithlord", name="Wraith Lord", rarity="Legendary", world="Shadow", body="ghost", move="float", idle="proud",
	c={"#1A0F2E","#6A2BC9","#FF3B6B"}, eyes="fierce", extra={"crown","spikes"}, fx="smoke", scale=1.35,
	desc="Commands an army of tiny shy shadows." }
add{ id="EclipseDragon", name="Eclipse Dragon", rarity="Mythical", world="Shadow", body="dragon", move="fly", idle="spin",
	c={"#000000","#FFB23B","#8A2BFF"}, horns="dragon", tail="stinger", wings="bat", eyes="glow", extra={"halo","rings"}, fx="smoke", scale=1.1,
	desc="When it flies over, day turns to night." }
add{ id="SeraphLion", name="Seraph Lion", rarity="Legendary", world="Heaven", body="quad", move="walk", idle="proud",
	c={"#FFF6DA","#FFFFFF","#FFC23B"}, ears="round", tail="fluffy", wings="angel", eyes="glow", extra={"mane","halo"}, fx="holy", scale=1.2,
	desc="Its golden mane glows brighter than the morning sun." }
add{ id="ThroneAngel", name="Throne Guardian", rarity="Mythical", world="Heaven", body="golem", move="float", idle="float",
	c={"#FFFFFF","#FFE9A6","#FFD24A"}, eyes="glow", wings="angel", extra={"halo","crown","crystal"}, mat="Marble", fx="holy", scale=1.15,
	desc="Has guarded Heaven's throne for ten thousand years." }

---------------------------------------------------------------- EXTRA SECRET + DIVINE
add{ id="NullBunny", name="Null Bunny", rarity="Secret", world="Any", body="round", move="hop", idle="bounce",
	c={"#000000","#FFFFFF","#FF003C"}, ears="bunny", tail="fluffy", eyes="cyclops", extra={"halo"}, mat="Neon", fx="glitch",
	desc="Exists in every portal at once. Nobody knows where it comes from." }
add{ id="TheWatcher", name="The Watcher", rarity="Secret", world="Any", body="ghost", move="float", idle="peek",
	c={"#0A0014","#00FFC8","#FF00AA"}, eyes="cyclops", extra={"rings","spikes"}, fx="glitch", scale=1.3,
	desc="It has seen you throw every single portal." }
add{ id="Genesis", name="Genesis", rarity="Divine", world="Any", body="dragon", move="fly", idle="float",
	c={"#FFFFFF","#FFD86B","#B8F3FF"}, horns="unicorn", tail="aurora", wings="angel", eyes="glow", extra={"halo","crown","rings","crystal"}, mat="Neon", fx="holy",
	desc="The creature that dreamed up all the other creatures." }
add{ id="Infinity", name="Infinity Fox", rarity="Divine", world="Any", body="quad", move="float", idle="spin",
	c={"#1A0F4A","#FF8AE2","#7DF9FF"}, ears="pointy", tail="aurora", eyes="glow", wings="angel", extra={"halo","rings","mane"}, mat="Glass", fx="stars",
	desc="It has nine tails, and each one holds a whole universe." }

---------------------------------------------------------------- index
local CreatureData = { List = L, ById = {}, ByWorld = {} }
for _, c in ipairs(L) do
	c.extra = c.extra or {}
	c.ears = c.ears or "none"; c.horns = c.horns or "none"; c.tail = c.tail or "none"; c.wings = c.wings or "none"
	c.eyes = c.eyes or "big"; c.scale = c.scale or 1
	CreatureData.ById[c.id] = c
	CreatureData.ByWorld[c.world] = CreatureData.ByWorld[c.world] or {}
	table.insert(CreatureData.ByWorld[c.world], c)
end

local Config = require(script.Parent.Config)

-- Income per second for one creature (before training multiplier)
function CreatureData.Income(id: string): number
	local c = CreatureData.ById[id]
	if not c then return 0 end
	local r = Config.Rarities[c.rarity].income
	local w = c.world == "Any" and 1 or Config.Worlds[c.world].incomeMult
	if c.world == "Any" then w = 120 end
	return r * w
end

return CreatureData
