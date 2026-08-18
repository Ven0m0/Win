# bedrock-packs.psd1 — Upstream sources for the Minecraft Bedrock packs installed in LeviLauncher
#
# Consumed by Scripts/Get-BedrockPackUpdate.ps1.
#
# Minecraft stores imported packs in base64-named folders and records nothing about where they came
# from, so this map has to be maintained by hand. Keys are the pack's `header.uuid` from its
# manifest.json — stable across reinstalls, unlike the folder name.
#
# LeviLauncher mods (<instance>\mods\<folder>\manifest.json) have no UUID at all, so their entries
# are keyed by the manifest's `name` instead - see the Mods section at the end of this file.
#
# Each entry is just a name and a URL. The script classifies the URL itself:
#
#   https://www.curseforge.com/minecraft-bedrock/<class>/<slug>  -> checked automatically via cfwidget
#   https://github.com/<owner>/<repo>                            -> checked automatically via releases API
#   anything else                                                -> reported as CHECK, open it yourself
#
# The CurseForge <class> is not always `addons`: Bedrock packs are spread across `addons`,
# `texture-packs` and `scripts`, so copy the project URL verbatim from the browser.
#
# Run the script with no arguments to list packs that aren't in here yet; each UNMAPPED row comes
# with a prefilled CurseForge search URL. Paste the project URL back in here to make it checkable.
#
# A behaviour pack and its matching resource pack are separate UUIDs but usually one CurseForge
# project, so they share a URL. Get-BedrockPackUpdate.ps1 caches upstream lookups by URL, so a
# shared BP/RP URL costs one network call, not two.

@{
  # ---------------------------------------------------------------------------
  # CurseForge — addons
  # ---------------------------------------------------------------------------
  '5f808eda-2eed-47b9-94ca-8486af1c5c14' = @{
    Name = 'Bedrock Essentials+ (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/bedrock-essentials'
  }
  '537af6fe-a865-4603-8847-37791b81249d' = @{
    Name = 'Bedrock Essentials+ (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/bedrock-essentials'
  }
  'ec49684a-b112-4b95-aa07-f298927dd02b' = @{
    Name = 'Age of Ocean Giants (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/age-of-ocean-giants'
  }
  '04b63cc0-3504-43b1-98a1-98b754ae6a86' = @{
    Name = 'Age of Ocean Giants (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/age-of-ocean-giants'
  }
  '4d498ac9-15b9-40e8-961f-f481ce2518f0' = @{
    Name = 'Cave Dweller Reimagined (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/cave-dweller-reimagined-bedrock-port-100-accurate'
  }
  '8f79756e-a96e-4d10-9ff2-f4279d999f8f' = @{
    Name = 'Cave Dweller Reimagined (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/cave-dweller-reimagined-bedrock-port-100-accurate'
  }
  '5bd7e353-2b7e-43f4-88fa-e98733e6ac02' = @{
    Name = 'Mutant Creatures Bedrock (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/mutant-creatures-addon'
  }
  '2fe0c00c-49b4-43a5-b264-d072d5fc1fb2' = @{
    Name = 'Mutant Creatures Bedrock (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/mutant-creatures-addon'
  }
  '5c98658f-909b-4709-924f-f08e829f0d97' = @{
    Name = 'Craftable Spawners (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/craftable-spawners'
  }
  '59e3c4b8-3daa-4a70-9ee8-2b5834b2b627' = @{
    Name = 'Craftable Spawners (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/craftable-spawners'
  }
  '5d2ddf02-dcd8-482e-92f7-4897320184d1' = @{
    Name = 'Java Enderman (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/java-enderman'
  }
  '6d770b31-94d2-4f4c-980f-1e41e0872fde' = @{
    Name = 'Java Enderman (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/java-enderman'
  }
  'dfdf61ca-d295-4744-838a-eeda7c8a2c6c' = @{
    Name = 'Skilled Items Deluxe (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/skilled-items-deluxe'
  }
  '64e0428f-25e0-469c-8e6f-5d0f51854df3' = @{
    Name = 'Skilled Items Deluxe (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/skilled-items-deluxe'
  }
  # V10 refreshed UUIDs (manifest description says so). Old V9 UUIDs dropped - only newest
  # instance gets checked.
  'e9e4a5b2-a153-41a0-a2c1-a569606ca677' = @{
    Name = 'Feather FPS Boost V10 (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/feather-fps-boost-mod'
  }
  'f78bd6c4-0c9d-45e8-8044-9dea2d49d691' = @{
    Name = 'Feather FPS Boost V10 (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/feather-fps-boost-mod'
  }
  '8596c16a-f92a-4dac-892d-5cafd38c9c7f' = @{
    Name = 'Magic Rings (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/magic-rings'
  }
  'da579260-0276-4b74-ad94-968a8bb212c2' = @{
    Name = 'Magic Rings (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/magic-rings'
  }
  '92b673f2-f243-4126-872e-57eba52537f8' = @{
    Name = 'Leashable Villagers'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/leashable-villagers'
  }
  'dde5c306-2eb2-4bcb-acb1-8eb1bb41994e' = @{
    Name = 'Long Distance Leash'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/long-distance-leash'
  }

  # More Tools Addon ships the base packs and the Wandering Trader extension from one project.
  '86bb4632-3521-443c-9b6a-c375e871ee64' = @{
    Name = 'More Tools Addon Balanced (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/more-tools-addon'
  }
  '4315677f-08d3-456d-b982-d3d21f39dbd2' = @{
    Name = 'More Tools Addon (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/more-tools-addon'
  }
  '02dc72a3-883b-9400-eefd-37da5c379d04' = @{
    Name = 'Wandering Trader / More Tools (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/more-tools-addon'
  }
  '2d080342-a267-dc78-b2ef-7a0a082c3704' = @{
    Name = 'Wandering Trader / More Tools (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/more-tools-addon'
  }

  # ---------------------------------------------------------------------------
  # CurseForge — dimzcraft. Split across addons, texture-packs and scripts.
  # ---------------------------------------------------------------------------
  '6185feef-1bb4-4139-9bd0-d423729e84cd' = @{
    Name = 'Door Air Pockets'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/door-air-pockets'
  }
  '36dd24b2-1791-4331-966b-94f885294833' = @{
    Name = 'Durability Tools Viewer'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/durability-tools-viewer'
  }
  'ab521cf5-dc95-4d56-aa73-2cfb1f96f12a' = @{
    Name = 'Recipe Book Plus'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/recipe-book-plus'
  }
  '876ba3a3-06ec-4b5f-9bfb-64f54b19eb7d' = @{
    Name = 'UI Neck'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/scripts/ui-neck'
  }

  # ---------------------------------------------------------------------------
  # CurseForge — texture-packs and scripts
  # ---------------------------------------------------------------------------
  '717d02e9-7f17-441b-b426-7d7e3d7d8237' = @{
    Name = 'Real FPS Counter'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/real-fps-counter'
  }
  '7f6b2c2f-3c8e-4e9d-9f0c-3b9b7f1e2c45' = @{
    Name = 'Villagers Trade Unlocker'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/villagers-trade-unlocker'
  }
  '94f456d4-7e0a-405b-b59d-508b4d53c064' = @{
    Name = 'Visible Powder Snow Pro'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/visible-powder-snow-pro'
  }
  '28d6db83-bcd4-490d-90cc-8dc7ac7dd44c' = @{
    Name = "PandaMine's Fog Remover"
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/pandamines-fog-remover'
  }
  'f3aeffce-f320-468a-9a76-bfc952548046' = @{
    Name = 'No Limits'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/scripts/no-limits'
  }

  # ---------------------------------------------------------------------------
  # CurseForge — lordraiyon69. Project slugs bear no resemblance to the pack names,
  # so these are only findable by browsing the author's profile.
  # ---------------------------------------------------------------------------
  'd7c85cdd-1e7d-47ed-8440-c779c1c41e7f' = @{
    Name = 'Armored Elytras (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyon-s-more-elytras-addon-1-20-80-compatible-with-other-addons-2'
  }
  '57da7897-09dd-4c12-9301-9b4e901702f0' = @{
    Name = 'Armored Elytras (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyon-s-more-elytras-addon-1-20-80-compatible-with-other-addons-2'
  }
  'f65e943a-2128-4da8-9196-e9bf5b86739d' = @{
    Name = 'Java Saturation (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyons-java-saturation-regeneration'
  }
  '9071b6bc-915d-4d26-8486-05bb8db48762' = @{
    Name = 'Java Saturation (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyons-java-saturation-regeneration'
  }

  # ---------------------------------------------------------------------------
  # CurseForge — remaining
  # ---------------------------------------------------------------------------
  'e78f0d37-d313-4b49-95e8-394b663e493e' = @{
    Name = 'Instant FullBright'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/instant-fullbright-night-vision-achievement-friendly'
  }
  '502beba6-d371-4b47-b7fe-242136a871a9' = @{
    Name = 'Clear Nether Portal'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/clear-nether-portals'
  }
  '94a8ab24-2cf3-434c-9f76-bf9c06b0a635' = @{
    Name = 'More Enchantments [V3.0] (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyon-s-more-enchantments-addon'
  }
  '2622459e-0a39-4728-bc65-fd26696454a2' = @{
    Name = 'More Enchantments [V3.0] (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/raiyon-s-more-enchantments-addon'
  }
  'b531dbeb-1ddc-45c9-b59d-13646280c6b0' = @{
    Name = 'Utility Chunks V4.0'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/scripts/utility-chunks'
  }
  '90d553cc-14c0-42c5-9fa1-34941a65c8cb' = @{
    Name = 'Old Netherite Upgrade | No Template'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/old-netherite-upgrade'
  }

  # Name matches exactly and it is the only Bedrock project called this, but the manifest
  # version (1.0.0) never moves while the author versions in the filename ([ v10 ]), so the
  # match is not corroborated by a version. Check the page before acting on an OUTDATED row.
  '343c099d-8a40-4ef0-b66c-d2b8ef8db69a' = @{
    Name = 'Armored Elytra Bedrock Edition (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/armored-elytra-bedrock-edition'
  }
  'd2ce1ff5-b92b-414a-ace0-fc194c396321' = @{
    Name = 'Armored Elytra Bedrock Edition (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/armored-elytra-bedrock-edition'
  }
  '7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d' = @{
    Name = 'Dynamic Health Bar (BP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/dynamic-health-bar'
  }
  'd3e4f5a6-b7c8-4d9e-a0f1-b2c3d4e5f6a7' = @{
    Name = 'Dynamic Health Bar (RP)'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/dynamic-health-bar'
  }
  '2a03bcd0-afa8-4daf-a53a-f08a67da8cbe' = @{
    Name = 'Infinite Villager Trades'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/addons/infinite-villager-trades'
  }
  'b09eee61-5648-79ef-bb61-269b8ae0d6c7' = @{
    Name = "PandaMine's Mip-Mapper"
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/pandamines-mip-mapper'
  }
  # Manifest credits both arne2655(YT) and Crazyy Hive(MCBEDROK); project is listed under CrazyyHi.
  '3308f7a1-427b-4bb9-bac2-90800fcb6428' = @{
    Name = 'Smaller Totem'
    Url  = 'https://www.curseforge.com/minecraft-bedrock/texture-packs/smaller-totem-and-shield'
  }

  # ---------------------------------------------------------------------------
  # GitHub
  # ---------------------------------------------------------------------------
  'bf898567-c2b5-4782-bc6b-a191fef3a483' = @{
    Name = 'Ender Chest Always Drops Itself'
    Url  = 'https://github.com/Ven0m0/mcpe'
  }
  'cd20dae0-2963-4f26-89e2-ecd808f5c74a' = @{
    Name = 'No Bat Spawn'
    Url  = 'https://github.com/Ven0m0/mcpe'
  }
  '29cdfca8-781e-4426-9921-20a53f74087c' = @{
    Name = 'Silk Touch Drops'
    Url  = 'https://github.com/Ven0m0/mcpe'
  }

  # ---------------------------------------------------------------------------
  # Not on CurseForge — manual check only
  #
  # Bedrock Tweaks generates a pack per download, so the stored link is one-shot;
  # regenerate from the site when the game version moves on.
  # ---------------------------------------------------------------------------
  '27289d58-785f-475b-aac8-1154667834b8' = @{ Name = 'Bedrock Tweaks (BP)'; Url = 'https://bedrocktweaks.net/' }
  'cb2ea8ed-f833-4ec1-ad4d-2af5521191a8' = @{ Name = 'Bedrock Tweaks (RP)'; Url = 'https://bedrocktweaks.net/' }

  # ---------------------------------------------------------------------------
  # When a pack looks absent from CurseForge, search by AUTHOR before concluding it
  # isn't there. Several projects here are titled nothing like the pack they install
  # ("Raiyon's Elytra Armor" ships "Armored Elytras"), and searching by pack name
  # surfaces same-named projects by unrelated authors instead. The author is usually
  # in the manifest description or the pack name itself.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # LeviLauncher mods (<instance>\mods\<folder>\manifest.json)
  #
  # Keyed by the manifest's `name` rather than a UUID - mod manifests have no UUID, and the
  # folder is named after the DLL the mod hijacks, not the project.
  # ---------------------------------------------------------------------------
  'Igneous' = @{
    Name = 'Igneous'
    Url  = 'https://github.com/Aetopia/Igneous'
  }
}
  # TODO: integrate flarial
  # flarial is from "https://github.com/flarialmc/newcdn/raw/refs/heads/main/dll/latest.dll"
