import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

import SlothsEggsBud from 0xf90c7d67bb1e8145
import SlothsEggsEgg from 0xf90c7d67bb1e8145

pub contract SlothsEggsSloths {

    pub event ContractInitialized()
    pub event PlayerInitialisedForRound(address: Address)
    pub event SlothsLevelUpBought(address: Address, addedLevels: { Int: Int })
    pub event SlothsBoosterBought(address: Address, boosterIndex: Int )
    
    access(account) var lastSeasonEnd: UFix64

    pub let DEV_ADDRESS: Address
    pub let MINING_PERIOD: UFix64
    pub let BOOSTER_PRICE_HALFING_TIME: UFix64

    pub let SLOTHS: {Int: Sloth}
    pub let SLOTH_BOOSTERS: {Int: SlothBooster}

    pub var playerLastEggsClaim: { Address: UFix64 }
    pub var playerSlothsLevel: { Address: [Int; 8] }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    pub fun getPlayerBooster(address: Address): SlothBooster? {
        var counter =  self.SLOTH_BOOSTERS.length -1
        while counter >= 0 {
            if(self.SLOTH_BOOSTERS[counter]!.currentOwner == address) {
                return self.SLOTH_BOOSTERS[counter]
            }
            counter = counter - 1
        }
        return nil
    }

    pub fun getPlayerBoosterIndex(address: Address): Int? {
        var counter =  self.SLOTH_BOOSTERS.length -1
        while counter >= 0 {
            if(self.SLOTH_BOOSTERS[counter]!.currentOwner == address) {
                return counter
            }
            counter = counter - 1
        }
        return nil
    }

    pub fun getPlayerEggProductionRate(address: Address): UFix64 {
        var counter = 0
        var totalProductionRate = 0.0
        if(self.playerSlothsLevel[address] == nil) {
          return 0.0
        }
        while counter < self.SLOTHS.length {
            totalProductionRate = totalProductionRate.saturatingAdd(self.SLOTHS[counter]!.productionRate.saturatingMultiply(UFix64(self.playerSlothsLevel[address]![counter]!)))
            counter = counter + 1
        }
        let playerBooster = self.getPlayerBooster(address: address)
        if(playerBooster != nil) {
            totalProductionRate = (totalProductionRate /100.0).saturatingMultiply(playerBooster!.boostRate)
        }
        return totalProductionRate
    }

    pub fun getProducedEggAmount(address: Address): UFix64 {
    if(self.playerLastEggsClaim[address] == nil) {
        return 0.0
      }
      let timeDiff = (self.playerLastEggsClaim[address]! < self.lastSeasonEnd ? self.lastSeasonEnd : getCurrentBlock().timestamp) - self.playerLastEggsClaim[address]!
      return (self.getPlayerEggProductionRate(address: address) / self.MINING_PERIOD).saturatingMultiply(timeDiff)
    }

    priv fun isPlayerInitialized(address: Address):Bool {
        return self.playerSlothsLevel[address] != nil && self.playerLastEggsClaim[address] != nil
    }

    priv fun getAddressFlowReceiverReference(address: Address): &FlowToken.Vault{FungibleToken.Receiver} {
      let flowVaultRef = getAccount(address)
        .getCapability(/public/flowTokenReceiver)!
        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
      return flowVaultRef!
    }
    
    access(account) fun setLastSeasonEnd(end: UFix64) {
      self.lastSeasonEnd = end
    }
    
    access(account) fun initPlayer(address: Address) {
        pre {
            self.isPlayerInitialized(address: address) == false : "player already initialised"
        }
        SlothsEggsEgg.createPlayerVault(address: address)
        self.playerSlothsLevel[address] = [0,0,0,0,0,0,0,0] as [Int; 8]
        self.playerLastEggsClaim[address] = getCurrentBlock().timestamp
    }
    
    access(account) fun initPlayerForNewRound(address: Address) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        self.playerLastEggsClaim[address] = getCurrentBlock().timestamp
        emit PlayerInitialisedForRound(address: address)
    }
    
    access(account) fun resetSlothsBoosterPrices() {
      for boosterIndex in self.SLOTH_BOOSTERS.keys {
        self.SLOTH_BOOSTERS[boosterIndex]?.setLastPrice(price: self.SLOTH_BOOSTERS[boosterIndex]?.basePrice! / 2.0)
      }
    }

    access(account) fun updatePlayer(address: Address) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        let producedEggAmount = self.getProducedEggAmount(address: address)
        // mint tokens for player
        if(producedEggAmount > 0.0) {
          SlothsEggsEgg.mintTokensForPlayer(amount: producedEggAmount, playerAddress: address)
        }
        self.playerLastEggsClaim[address] = getCurrentBlock().timestamp
    }

    access(account) fun buyEggProductionBooster(address: Address, index: Int) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
            index >= 0 && index < 5
        }
        self.updatePlayer(address: address)
        self.SLOTH_BOOSTERS[index]?.setLastPrice(price: self.SLOTH_BOOSTERS[index]?.getFlowPrice()!)
        self.SLOTH_BOOSTERS[index]?.setCurrentOwner(address: address)
        emit SlothsBoosterBought(address: address, boosterIndex: index )
    }

    access(account) fun levelUpSloths(address: Address, addedLevels: {Int: Int}) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        self.updatePlayer(address: address)

        var totalBudPrice = 0.0
        var playerSlothsLevel = self.playerSlothsLevel[address]!
        for slothIndex in addedLevels.keys {
            // check limit
            if(playerSlothsLevel[slothIndex]! + addedLevels[slothIndex]! > self.SLOTHS[slothIndex]!.maxLevel) {
                panic("error.over.max.level")
            }
            totalBudPrice = totalBudPrice + self.SLOTHS[slothIndex]!.upgradeCostBud * UFix64(addedLevels[slothIndex]!)
            playerSlothsLevel[slothIndex] = playerSlothsLevel[slothIndex]! + addedLevels[slothIndex]!
        }
        // check available buds
        let playerBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        if(totalBudPrice > playerBudVaultRef!.balance) {
          panic("error.enough.buds")
        }
        var paymentBudsVault <- playerBudVaultRef!.withdraw(amount: totalBudPrice)
        // destroy the received buds
        destroy paymentBudsVault

        self.playerSlothsLevel[address] = playerSlothsLevel
        emit SlothsLevelUpBought(address: address, addedLevels: addedLevels)
    }

    pub struct Sloth {
        pub let productionRate: UFix64
        pub let upgradeCostBud: UFix64
        pub let upgradeCostFlow: UFix64
        pub let maxLevel: Int
        init(productionRate: UFix64,upgradeCostBud: UFix64, upgradeCostFlow: UFix64, maxLevel: Int) {
            self.productionRate = productionRate
            self.upgradeCostBud = upgradeCostBud
            self.upgradeCostFlow = upgradeCostFlow
            self.maxLevel = maxLevel
        }
    }

    pub struct SlothBooster {
        pub let boostRate: UFix64
        pub let basePrice: UFix64
        pub var lastPrice: UFix64
        pub var lastPriceUpdate: UFix64
        pub var currentOwner: Address

        pub fun getFlowPrice():UFix64 {
            // price is doubled after buy
            // after BOOSTER_PRICE_HALFING_TIME time is halved until basePrice
            let currentTime = getCurrentBlock().timestamp
            if(self.lastPriceUpdate + SlothsEggsSloths.BOOSTER_PRICE_HALFING_TIME > currentTime) {
                return self.lastPrice * 2.0
            } else {
                let doublePriceEndTime = self.lastPriceUpdate + SlothsEggsSloths.BOOSTER_PRICE_HALFING_TIME
                let numOfHalvingPeriods = Int64((currentTime - doublePriceEndTime) / SlothsEggsSloths.BOOSTER_PRICE_HALFING_TIME)
                var currentPrice = self.lastPrice
                var counter = 0 as Int64
                while(counter <= numOfHalvingPeriods && currentPrice > self.basePrice) {
                    currentPrice = currentPrice / 2.0
                    counter = counter + 1
                }
                return currentPrice
            }
        }

        access(contract) fun setCurrentOwner(address: Address) {
            self.currentOwner = address
        }

        access(contract) fun setLastPrice(price: UFix64) {
            self.lastPrice = price
            self.lastPriceUpdate = getCurrentBlock().timestamp
        }

        init(boostRate: UFix64, basePrice: UFix64) {
            self.basePrice = basePrice
            self.lastPrice = basePrice
            self.boostRate = boostRate
            self.lastPriceUpdate = 0.0
            self.currentOwner = SlothsEggsSloths.DEV_ADDRESS
        }
    }
    
    init() {
        self.lastSeasonEnd = 0.0
        self.DEV_ADDRESS = self.account.address
        self.MINING_PERIOD = 86400.0 // one day 60 * 60* 60
        self.BOOSTER_PRICE_HALFING_TIME = 43200.0 // 86400
        self.SLOTHS = {
            0: Sloth(productionRate: 10.0, upgradeCostBud: 10.0, upgradeCostFlow: 0.0, maxLevel: 10),
            1: Sloth(productionRate: 335.6, upgradeCostBud: 100.0, upgradeCostFlow: 0.1, maxLevel: 2),
            2: Sloth(productionRate: 839.0, upgradeCostBud: 1000.0, upgradeCostFlow: 0.2, maxLevel: 4),
            3: Sloth(productionRate: 2097.2, upgradeCostBud: 4000.0, upgradeCostFlow: 0.4, maxLevel: 8),
            4: Sloth(productionRate: 5243.0, upgradeCostBud: 16000.0, upgradeCostFlow: 0.8, maxLevel: 16),
            5: Sloth(productionRate: 13107.2, upgradeCostBud: 64000.0, upgradeCostFlow: 1.6, maxLevel: 32),
            6: Sloth(productionRate: 32768.0, upgradeCostBud: 240000.0, upgradeCostFlow: 2.4, maxLevel: 64),
            7: Sloth(productionRate: 81920.0, upgradeCostBud: 1000000.0, upgradeCostFlow: 3.2, maxLevel: 256)
        }
        self.SLOTH_BOOSTERS = {
            0: SlothBooster(boostRate: 150.0, basePrice: 0.1),
            1: SlothBooster(boostRate: 175.0, basePrice: 0.2),
            2: SlothBooster(boostRate: 200.0, basePrice: 0.4),
            3: SlothBooster(boostRate: 225.0, basePrice: 0.8),
            4: SlothBooster(boostRate: 250.0, basePrice: 1.6)
        }

        self.playerSlothsLevel = {}
    	  self.playerLastEggsClaim = {}

        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsSlothsAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsSlothsAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}