import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

import SlothsEggsBud from 0xf90c7d67bb1e8145

pub contract SlothsEggsBushmen {

    pub event ContractInitialized()
    pub event PlayerInitialisedForRound(address: Address)
    pub event BushmenLevelUpBought(address: Address, addedLevels: { Int: Int })
    pub event BushmenBoosterBought(address: Address, boosterIndex: Int )
    pub event BushmenBoosterPricesReset()
    

    access(account) var lastSeasonEnd: UFix64
    pub let DEV_ADDRESS: Address
    pub let MINING_PERIOD: UFix64
    pub let BOOSTER_PRICE_HALFING_TIME: UFix64

    pub let BUSHMEN: {Int: Bushman}
    pub let BUSHMAN_BOOSTERS: {Int: BushmanBooster}

    pub var playerLastBudsClaim: { Address: UFix64 }
    pub var playerBushmenLevel: { Address: [Int; 8] }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    pub fun getPlayerBooster(address: Address): BushmanBooster? {
        var counter =  self.BUSHMAN_BOOSTERS.length - 1
        while counter >= 0 {
            if(self.BUSHMAN_BOOSTERS[counter]!.currentOwner == address) {
                return self.BUSHMAN_BOOSTERS[counter]
            }
            counter = counter - 1
        }
        return nil
    }

    pub fun getPlayerBoosterIndex(address: Address): Int? {
        var counter =  self.BUSHMAN_BOOSTERS.length -1
        while counter >= 0 {
            if(self.BUSHMAN_BOOSTERS[counter]!.currentOwner == address) {
                return counter
            }
            counter = counter - 1
        }
        return nil
    }

    pub fun getPlayerBudProductionRate(address: Address): UFix64 {
        var counter = 0
        var totalProductionRate = 0.0
        if(self.playerBushmenLevel[address] == nil) {
          return 0.0
        }
        while counter < self.BUSHMEN.length {
            totalProductionRate = totalProductionRate.saturatingAdd(self.BUSHMEN[counter]!.productionRate.saturatingMultiply(UFix64(self.playerBushmenLevel[address]![counter]!)))
            counter = counter + 1
        }
        let playerBooster = self.getPlayerBooster(address: address)
        if(playerBooster != nil) {
            totalProductionRate = (totalProductionRate / 100.0).saturatingMultiply(playerBooster!.boostRate)
        }
        return totalProductionRate
    }
    
    pub fun getTopTenPlayers(playerAddresses: [Address]): [Address] {
      var topTenPlayerResult: [Address] = []
      var addressCounter = 0
      while addressCounter < playerAddresses.length {
        var resultCounter = 0
        while  resultCounter < topTenPlayerResult.length {
          if(self.getPlayerBudProductionRate(address: playerAddresses[addressCounter]!) > self.getPlayerBudProductionRate(address: topTenPlayerResult[resultCounter]!)) {
            break
          }
          resultCounter = resultCounter + 1
        }
        topTenPlayerResult.insert(at: resultCounter, playerAddresses[addressCounter]!)
        if(topTenPlayerResult.length > 10) {
          topTenPlayerResult.remove(at: 10)
        }
        addressCounter = addressCounter + 1
      }
      return topTenPlayerResult
    }

    pub fun getProducedBudAmount(address: Address): UFix64 {
      if(self.playerLastBudsClaim[address] == nil) {
        return 0.0
      }
      let timeDiff = (self.playerLastBudsClaim[address]! < self.lastSeasonEnd ? self.lastSeasonEnd : getCurrentBlock().timestamp) - self.playerLastBudsClaim[address]!
      return (self.getPlayerBudProductionRate(address: address) / self.MINING_PERIOD).saturatingMultiply(timeDiff)
    }

    priv fun isPlayerInitialized(address: Address):Bool {
        return self.playerBushmenLevel[address] != nil && self.playerLastBudsClaim[address] != nil
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
        SlothsEggsBud.createPlayerVault(address: address)
        self.playerBushmenLevel[address] = [0,0,0,0,0,0,0,0] as [Int; 8]
        self.playerLastBudsClaim[address] = getCurrentBlock().timestamp
    }
    
    access(account) fun initPlayerForNewRound(address: Address) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        let playerVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        if(playerVaultRef.balance > 0.0) {
          destroy playerVaultRef.withdraw(amount:playerVaultRef.balance)
        }
        
        self.playerBushmenLevel[address] = [1,0,0,0,0,0,0,0] as [Int; 8]
        self.playerLastBudsClaim[address] = getCurrentBlock().timestamp
        emit PlayerInitialisedForRound(address: address)
    }
    
    access(account) fun resetBushmenBoosterPrices() {
      for boosterIndex in self.BUSHMAN_BOOSTERS.keys {
        self.BUSHMAN_BOOSTERS[boosterIndex]?.setLastPrice(price: self.BUSHMAN_BOOSTERS[boosterIndex]?.basePrice! / 2.0)
      }
      emit BushmenBoosterPricesReset()
    }
    
    access(account) fun setBushmanBoosterOwnerAndLevelUpPrice(index: Int, address: Address) {
      self.BUSHMAN_BOOSTERS[index]?.setCurrentOwner(address: address)
      self.BUSHMAN_BOOSTERS[index]?.setLastPrice(price: self.BUSHMAN_BOOSTERS[index]?.basePrice! * 2.0)
    }

    access(account) fun updatePlayer(address: Address) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        let producedBudAmount = self.getProducedBudAmount(address: address)
        // mint tokens for player
        if(producedBudAmount > 0.0) {
          SlothsEggsBud.mintTokensForPlayer(amount: producedBudAmount, playerAddress: address)
        }
        self.playerLastBudsClaim[address] = getCurrentBlock().timestamp
    }

    access(account) fun buyBudProductionBooster(address: Address, index: Int) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
            index >= 0 && index < 5
        }
        self.updatePlayer(address: address)
        self.BUSHMAN_BOOSTERS[index]?.setLastPrice(price: self.BUSHMAN_BOOSTERS[index]?.getFlowPrice()!)
        self.BUSHMAN_BOOSTERS[index]?.setCurrentOwner(address: address)
        emit BushmenBoosterBought(address: address, boosterIndex: index )
    }

    access(account) fun levelUpBushmen(address: Address, addedLevels: {Int: Int}) {
        pre {
            self.isPlayerInitialized(address: address) == true : "player not initialised"
        }
        self.updatePlayer(address: address)

        var totalBudPrice = 0.0
        var playerBushmenLevel = self.playerBushmenLevel[address]!
        for bushmanIndex in addedLevels.keys {
            // check limit
            if(playerBushmenLevel[bushmanIndex]! + addedLevels[bushmanIndex]! > self.BUSHMEN[bushmanIndex]!.maxLevel) {
                panic("error.over.max.level")
            }
            totalBudPrice = totalBudPrice + self.BUSHMEN[bushmanIndex]!.upgradeCostBud * UFix64(addedLevels[bushmanIndex]!)
            playerBushmenLevel[bushmanIndex] = playerBushmenLevel[bushmanIndex]! + addedLevels[bushmanIndex]!
            
        }
        // check available buds
        let playerBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        if(totalBudPrice > playerBudVaultRef.balance) {
          panic("error.enough.buds")
        }
        var paymentBudsVault <- playerBudVaultRef!.withdraw(amount: totalBudPrice)
        // destroy the received buds
        destroy paymentBudsVault
        
        emit BushmenLevelUpBought(address: address, addedLevels: addedLevels)
        self.playerBushmenLevel[address] = playerBushmenLevel
    }
    
    access(account) fun decreasePlayerBushmanLevel(address: Address, index: Int) {
      let playerLevels = self.playerBushmenLevel[address]!
      if(playerLevels[index]  > 0) {
        playerLevels[index] = playerLevels[index] - 1
      }
      self.playerBushmenLevel[address] = playerLevels
    }

    pub struct Bushman {
        pub let productionRate: UFix64
        pub let upgradeCostBud: UFix64
        pub let maxLevel: Int
        init(productionRate: UFix64,upgradeCostBud: UFix64,maxLevel: Int) {
            self.productionRate = productionRate
            self.upgradeCostBud = upgradeCostBud
            self.maxLevel = maxLevel
        }
    }

    pub struct BushmanBooster {
        pub let boostRate: UFix64
        pub let basePrice: UFix64
        pub var lastPrice: UFix64
        pub var lastPriceUpdate: UFix64
        pub var currentOwner: Address

        pub fun getFlowPrice():UFix64 {
            // price is doubled after buy
            // after BOOSTER_PRICE_HALFING_TIME time is halved until basePrice
            let currentTime = getCurrentBlock().timestamp
            if(self.lastPriceUpdate + SlothsEggsBushmen.BOOSTER_PRICE_HALFING_TIME > currentTime) {
                return self.lastPrice * 2.0
            } else {
                let doublePriceEndTime = self.lastPriceUpdate + SlothsEggsBushmen.BOOSTER_PRICE_HALFING_TIME
                let numOfHalvingPeriods = Int64((currentTime - doublePriceEndTime) / SlothsEggsBushmen.BOOSTER_PRICE_HALFING_TIME)
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
            self.currentOwner = SlothsEggsBushmen.DEV_ADDRESS
        }
    }
    
    init() {
        self.DEV_ADDRESS = self.account.address
        self.MINING_PERIOD = 86400.0 // one day 60 * 60* 60
        self.BOOSTER_PRICE_HALFING_TIME = 43200.0 // 86400
        self.BUSHMEN = {
            0: Bushman(productionRate: 10.0, upgradeCostBud: 10.0, maxLevel: 10),
            1: Bushman(productionRate: 200.0, upgradeCostBud: 50.0, maxLevel: 2),
            2: Bushman(productionRate: 800.0, upgradeCostBud: 200.0, maxLevel: 4),
            3: Bushman(productionRate: 3200.0, upgradeCostBud: 800.0, maxLevel: 8),
            4: Bushman(productionRate: 9600.0, upgradeCostBud: 3200.0, maxLevel: 16),
            5: Bushman(productionRate: 38400.0, upgradeCostBud: 12800.0, maxLevel: 32),
            6: Bushman(productionRate: 204800.0, upgradeCostBud: 102400.0, maxLevel: 64),
            7: Bushman(productionRate: 819200.0, upgradeCostBud: 819200.0, maxLevel: 256)
        }
        self.BUSHMAN_BOOSTERS = {
            0: BushmanBooster(boostRate: 150.0, basePrice: 0.05),
            1: BushmanBooster(boostRate: 175.0, basePrice: 0.1),
            2: BushmanBooster(boostRate: 200.0, basePrice: 0.2),
            3: BushmanBooster(boostRate: 225.0, basePrice: 0.4),
            4: BushmanBooster(boostRate: 250.0, basePrice: 0.8)
        }

        self.lastSeasonEnd = 0.0
        self.playerBushmenLevel = {}
    	self.playerLastBudsClaim = {}

        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsBushmenAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsBushmenAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}