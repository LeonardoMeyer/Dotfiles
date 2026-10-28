-- Perfil do PC do Hex: dois monitores lado a lado
-- HDMI-A-1: 1920x1080 a 100 Hz, à esquerda
-- HDMI-A-2: 1920x1080 a 144 Hz, à direita
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@100", position = "0x0", scale = 1.00 })
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@143.98", position = "1920x0", scale = 1.00 })

return {
    -- padrões; o painel de configurações (Alt+S) pode sobrescrever
    defaults = {
        boot = { enabled = true, black_ms = 1500 },
        cursor = { theme = "Bibata-Modern-Ice", size = 20 },
    },
    sensitivity = 0,
}
