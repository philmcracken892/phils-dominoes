Config = {}


Config.Tables = {
    
    {
        id = 1,
        coords = vector3(-815.43, -1324.77, 47.88), -- Blackwater upstairs
        heading = 270.0,
        minBet = 5,
        maxBet = 250,
        maxPlayers = 2,
        allowAI = true
    },
	
	 {
        id = 2,
        coords = vector3(-311.84, 800.09, 118.99), -- VALENTINE
        heading = 270.0,
        minBet = 5,
        maxBet = 250,
        maxPlayers = 2,
        allowAI = true
    }
}


Config.GameSettings = {
    startingTiles = 7,
    maxScore = 100,
    turnTimer = 30, -- seconds
    joinRadius = 2.0
}


Config.AI = {
    enabled = true,
    maxAIPlayers = 3,
    difficulties = {
        easy = {
            thinkTime = {min = 1500, max = 3000},
            skillLevel = 0.3
        },
        medium = {
            thinkTime = {min = 1000, max = 2000},
            skillLevel = 0.7
        },
        hard = {
            thinkTime = {min = 500, max = 1500},
            skillLevel = 0.95
        }
    }
}


Config.AINames = {
    "phil mcracken",
    "Mack Black",
    "Jesse James",
    "Wyatt Earp",
    "Buffalo Bill",
    "Calamity Jane",
    "Annie Oakley",
    "Billy the Kid",
    "Butch Cassidy",
    "Sundance Kid",
    "Black Bart",
    "Pearl Hart",
    "Belle Starr",
    "John Wesley Hardin",
    "Pat Garrett"
}

-- Rewards
Config.Rewards = {
    winMultiplier = 2.0,
    drawReturn = 1.0
}
