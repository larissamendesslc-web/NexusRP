NEXUS_AUTH_CONFIG = {
    brand = "NexusRP",
    subtitle = "UMA NOVA HISTÓRIA COMEÇA AQUI",
    accent = "#8B5CF6",

    -- Usado somente quando não existem outros arquivos para baixar.
    noDownloadFallbackMs = 3500,

    usernameMinLength = 3,
    usernameMaxLength = 24,
    passwordMinLength = 6,
    passwordMaxLength = 30,

    characterNameMinLength = 5,
    characterNameMaxLength = 40,
    minimumAge = 18,
    maximumAge = 80,

    maxAttempts = 5,
    blockSeconds = 30,

    -- Os dois personagens disponíveis nesta primeira versão.
    characters = {
        male = {
            label = "Masculino",
            skin = 60
        },
        female = {
            label = "Feminino",
            skin = 56
        }
    },

    -- Aeroporto Internacional de Los Santos.
    airportSpawn = {
        x = 1686.38,
        y = -2334.49,
        z = 13.55,
        rotation = 0,
        interior = 0,
        dimension = 0
    },

    camera = {
        x = 1474.0,
        y = -1747.0,
        z = 31.0,
        lookX = 1481.1,
        lookY = -1771.6,
        lookZ = 18.8
    }
}
