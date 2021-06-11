pub contract SlothsEggsSponsor {

    pub event ContractInitialized()
    pub event GameSponsorBought(address: Address)

    pub let GAME_SPONSOR_BASE_PRICE: UFix64
    pub let GAME_SPONSOR_PRICE_UP_PERCENT: UFix64
    pub var currentPrices: {String: UFix64}
    pub var currentGameSponsorAddresses: {String: Address}
    
    access(account) fun setGameSponsorAndNewPrice(address: Address) {
        pre {
            self.currentGameSponsorAddresses["gameSponsor"] != address : "error.you.are.already.sponsor"
        }
        self.currentGameSponsorAddresses["gameSponsor"] = address
        self.currentPrices["gameSponsor"] = self.currentPrices["gameSponsor"]! / 100.0 * self.GAME_SPONSOR_PRICE_UP_PERCENT
        emit GameSponsorBought(address: address)
    }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.GAME_SPONSOR_BASE_PRICE= 0.01
        self.GAME_SPONSOR_PRICE_UP_PERCENT= 150.0
        self.currentPrices= {
            "gameSponsor": self.GAME_SPONSOR_BASE_PRICE
        }
        self.currentGameSponsorAddresses = {
            "gameSponsor": self.account.address
        }

        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsSponsorAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsSponsorAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}