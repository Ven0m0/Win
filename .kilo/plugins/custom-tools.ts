import type { Plugin } from "@opencode-ai/plugin";
import jsonRepair from "../tools/json_repair";
import hlEdit from "../tools/hashline_edit";
import { read as hlRead, grep as hlGrep } from "../tools/hashline_rg";

const CustomToolsPlugin: Plugin = async () => ({
  tool: {
    json_repair: jsonRepair,
    hl_edit: hlEdit,
    hl_read: hlRead,
    hl_grep: hlGrep,
  },
});

export default CustomToolsPlugin;
