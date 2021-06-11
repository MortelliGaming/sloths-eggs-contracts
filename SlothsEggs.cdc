
import FlowToken from 0x7e60df042a9c0868
import FungibleToken from 0x9a0766d93b6608b7

import SlothsEggsBud from 0xf90c7d67bb1e8145
import SlothsEggsEgg from 0xf90c7d67bb1e8145
import SlothsEggsSloths from 0xf90c7d67bb1e8145
import SlothsEggsBushmen from 0xf90c7d67bb1e8145
import SlothsEggsBudAirdrop from 0xf90c7d67bb1e8145
import SlothsEggsSponsor from 0xf90c7d67bb1e8145
import SlothsEggsBudStake from 0xf90c7d67bb1e8145
import SlothsEggsBoss from 0xf90c7d67bb1e8145
import SlothsEggsPvP from 0xf90c7d67bb1e8145
import SlothsEggsPrizePools from 0xf90c7d67bb1e8145
import SlothsEggsAttackPerks from 0xf90c7d67bb1e8145

pub contract SlothsEggs {
    pub event DevPayment(amount: UFix64)
    pub event SponsorPayment(amount: UFix64)
    pub event BudStakeBurnt()
    pub event PlayerPaymentFromBudStakingPool(address: Address, amount: UFix64)
    pub event PlayerPaymentFromBudProductionPool(address: Address, amount: UFix64)
    pub event PlayerPaymentFromBudBossKillPool(address: Address, amount: UFix64)
    pub event DepositedToReserveVault(amount: UFix64)
    pub event DepositedToBossKillPool(amount: UFix64)
    pub event DepositedToBudStakingPool(amount: UFix64)
    pub event DepositedToTopBudProductionPool(amount: UFix64)
    pub event SeasonEnded()
    pub event SeasonStarted()
    pub event UserEnteredSeason(address: Address, username: String)
    

    pub let DEV_ADDRESS: Address
    pub let GAME_START_TIME: UFix64
    pub let SEASION_DURATION: UFix64
    
    pub var lastSeasonStart: UFix64
    pub var roundPlayers: [Address]
    pub var userNames: { Address: String }
    

    priv fun getAddressFlowReceiverReference(address: Address): &FlowToken.Vault{FungibleToken.Receiver} {
      let flowVaultRef = getAccount(address)
        .getCapability(/public/flowTokenReceiver)!
        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
      return flowVaultRef!
    }

    access(contract) fun handleSponsorPayment(paymentVault: @FlowToken.Vault) {
        let gameSponsorRef = self.getAddressFlowReceiverReference(address: SlothsEggsSponsor.currentGameSponsorAddresses["gameSponsor"]!)
        // 110% of last purchase price
        let sponsorFeeAmount = paymentVault.balance * 110.0 / SlothsEggsSponsor.GAME_SPONSOR_PRICE_UP_PERCENT
        gameSponsorRef!.deposit(from: <- paymentVault.withdraw(amount: sponsorFeeAmount))
        emit SponsorPayment(amount: sponsorFeeAmount)
        let devRef = self.getAddressFlowReceiverReference(address: self.DEV_ADDRESS)
        devRef.deposit(from: <- paymentVault)
    }

    access(contract) fun setUsername(address: Address, name: String) {
        pre {
          self.userNames.values.contains(name) == false: "error.username.already.in.use"
        }
        self.userNames[address] = name
    }

    access(contract) fun addRoundPlayer(address: Address) {
        pre {
            self.roundPlayers.contains(address) == false: "error.already.registered.for.round"
        }
        self.roundPlayers.append(address)
    }

    access(contract) fun endRound(address: Address) {
        self.distributeTopTenPool()

        SlothsEggsBushmen.setLastSeasonEnd(end: self.lastSeasonStart + self.SEASION_DURATION)
        SlothsEggsSloths.setLastSeasonEnd(end: self.lastSeasonStart + self.SEASION_DURATION)
        self.startNewSeason(address: address)
        emit SeasonEnded()
    }

    access(contract) fun distributeTopTenPool() {
        let topTenAddresses = SlothsEggsBushmen.getTopTenPlayers(playerAddresses: self.roundPlayers)
        let budProductionPrizePoolRef = SlothsEggsPrizePools.getPrizeVaultReference(name: "topBudProductionPool")
        var counter = 0
        for topTenAddress in topTenAddresses {
            let playerFlowVaultRef = self.getAddressFlowReceiverReference(address: self.DEV_ADDRESS)
            var playerAmount = 0.0
            if(counter == 0) {
              playerAmount = budProductionPrizePoolRef.balance * 0.25
            }
            else if(counter == 1) {
              playerAmount = budProductionPrizePoolRef.balance * 0.20
            }
            else if(counter == 2) {
              playerAmount = budProductionPrizePoolRef.balance * 0.15
            }
            else if(counter == 3) {
              playerAmount = budProductionPrizePoolRef.balance * 0.08
            }
            else if(counter == 4) {
              playerAmount = budProductionPrizePoolRef.balance * 0.07
            }
            else {
              playerAmount = budProductionPrizePoolRef.balance * 0.05
            }
            playerFlowVaultRef.deposit(from: <- budProductionPrizePoolRef.withdraw(amount: playerAmount))
            counter = counter + 1
            emit PlayerPaymentFromBudProductionPool(address: topTenAddress, amount: playerAmount)
        }
        if(budProductionPrizePoolRef.balance > 0.0) {
          let devRef = self.getAddressFlowReceiverReference(address: self.DEV_ADDRESS)
          devRef.deposit(from: <- budProductionPrizePoolRef.withdraw(amount: budProductionPrizePoolRef.balance))
        }
    }

    access(contract) fun startNewSeason(address: Address) {
        self.roundPlayers = []
        SlothsEggsSloths.resetSlothsBoosterPrices()
        SlothsEggsBushmen.resetBushmenBoosterPrices()
        SlothsEggsBushmen.setBushmanBoosterOwnerAndLevelUpPrice(index: 4, address: address)
        SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 100.0, bossPoolPercent: 0.0, budStakingPoolPercent: 0.0, dripPercent: 7.5)
        self.lastSeasonStart = getCurrentBlock().timestamp
        emit SeasonStarted()
    }
    
    pub fun hasGameStarted(): Bool {
        return self.GAME_START_TIME <= getCurrentBlock().timestamp
    }

    pub fun hasSeasonEnded(): Bool {
        return self.lastSeasonStart + self.SEASION_DURATION < getCurrentBlock().timestamp
    }
    
    pub fun createPlayerToken(): @PlayerToken {
      return <- (create PlayerToken())
    }
    
    pub resource PlayerToken {
        priv fun preparePlayer() {
            SlothsEggsBud.createPlayerVault(address: self.owner!.address)
            SlothsEggsEgg.createPlayerVault(address: self.owner!.address)
            SlothsEggsSloths.initPlayer(address: self.owner!.address)
            SlothsEggsBushmen.initPlayer(address: self.owner!.address)
            SlothsEggsBudAirdrop.initPlayer(address: self.owner!.address)
            SlothsEggsAttackPerks.initPlayer(address: self.owner!.address)
        }
        
        priv fun updatePlayer() {
            SlothsEggsSloths.updatePlayer(address: self.owner!.address)
            SlothsEggsBushmen.updatePlayer(address: self.owner!.address)
            SlothsEggsAttackPerks.updatePlayer(address: self.owner!.address)
        }

        pub fun registerForRoundAndGetFreeBushman(username: String?) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == false: "error.already.registered.for.round"
            }
            if(SlothsEggs.userNames[self.owner!.address] == nil) {
                SlothsEggs.setUsername(address: self.owner!.address, name: self.owner!.address.toString())
                self.preparePlayer()
            }
            self.updatePlayer()
            if(username != nil) {
                SlothsEggs.setUsername(address: self.owner!.address, name: username!)
            }
            SlothsEggsBushmen.initPlayerForNewRound(address: self.owner!.address)
            SlothsEggsSloths.initPlayerForNewRound(address: self.owner!.address)
            SlothsEggs.addRoundPlayer(address: self.owner!.address)
            emit UserEnteredSeason(address: self.owner!.address, username: (username != nil ? username! : self.owner!.address.toString()))
        }

        
        pub fun claimBudAirdrop() {
          pre {
              SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
              SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
          }
          self.updatePlayer()
          SlothsEggsBudAirdrop.claimBudAirdrop(address: self.owner!.address)
        }
        
        pub fun upgradeBushmen(bushmenUpgradeLevels: {Int: Int}) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
            }
            self.updatePlayer()
            SlothsEggsBushmen.levelUpBushmen(address: self.owner!.address, addedLevels: bushmenUpgradeLevels)
        }

        pub fun buyBudProductionBooster(index: Int, paymentVault: @FlowToken.Vault) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
                SlothsEggsBushmen.BUSHMAN_BOOSTERS[index]!.getFlowPrice() <= paymentVault.balance : "error.payment.too.low" 
            }
            self.updatePlayer()
            let holderRewardAmount = SlothsEggsBushmen.BUSHMAN_BOOSTERS[index]!.getFlowPrice() / 100.0 * 55.0
            let holderAddress = SlothsEggsBushmen.BUSHMAN_BOOSTERS[index]!.currentOwner
            SlothsEggsPrizePools.getAddressFlowReceiverReference(address: holderAddress).deposit(from: <- paymentVault.withdraw(amount: holderRewardAmount))
            SlothsEggsBushmen.buyBudProductionBooster(address: self.owner!.address, index: index)
            if(paymentVault.balance > 0.0) {
              SlothsEggsPrizePools.distributeToDevAndSponsorAndReserveVault(paymentVault: <- paymentVault)
              SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 100.0, bossPoolPercent: 0.0, budStakingPoolPercent: 0.0, dripPercent: 2.0)
            } else {
              destroy paymentVault
            }
        }
        
        pub fun upgradeSloths(addedLevels: {Int: Int}, paymentVault: @FlowToken.Vault) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
            }
            self.updatePlayer()
            var totalFlowPrice = 0.0
            for slothIndex in addedLevels.keys {
                // check limit
                totalFlowPrice = totalFlowPrice + SlothsEggsSloths.SLOTHS[slothIndex]!.upgradeCostFlow * UFix64(addedLevels[slothIndex]!)
            }
            if(paymentVault.balance < totalFlowPrice) {
              panic("error.flow.balance.too.low")
            }
            SlothsEggsSloths.levelUpSloths(address: self.owner!.address, addedLevels: addedLevels)
            if(paymentVault.balance > 0.0) {
              SlothsEggsPrizePools.distributeToDevAndSponsorAndReserveVault(paymentVault: <- paymentVault)
              SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 100.0, bossPoolPercent: 0.0, budStakingPoolPercent: 0.0, dripPercent: 2.0)
            } else {
              destroy paymentVault
            }
            
        }

        pub fun buyEggProductionBooster(index: Int, paymentVault: @FlowToken.Vault) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
                SlothsEggsSloths.SLOTH_BOOSTERS[index]!.getFlowPrice() <= paymentVault.balance : "error.payment.too.low" 
            }
            self.updatePlayer()
            SlothsEggsSloths.buyEggProductionBooster(address: self.owner!.address, index: index)
            
            if(paymentVault.balance > 0.0) {
              SlothsEggsPrizePools.distributeToDevAndSponsorAndReserveVault(paymentVault: <- paymentVault)
              SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 100.0, bossPoolPercent: 0.0, budStakingPoolPercent: 0.0, dripPercent: 2.0)
            } else {
              destroy paymentVault
            }
        }
        
        pub fun buyGameSponsor(paymentVault: @FlowToken.Vault) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
                SlothsEggsSponsor.currentPrices["gameSponsor"]! <= paymentVault.balance : "error.payment.too.low" 
            }
            self.updatePlayer()
            SlothsEggs.handleSponsorPayment(paymentVault: <- paymentVault)
            SlothsEggsSponsor.setGameSponsorAndNewPrice(address: self.owner!.address)
            // make reserve drip to pools
            // SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 10.0, bossPoolPercent: 10.0, budStakingPoolPercent: 80.0, dripPercent: 5.0)
        }
        
        pub fun addPlayerBudStake(amount: UFix64) {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
            }
            self.updatePlayer()
          SlothsEggsBudStake.addPlayerBudStake(address: self.owner!.address, amount: amount)
        }
        
        pub fun attackBoss(amount: UFix64) {
          pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
                SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
            }
            self.updatePlayer()
            SlothsEggsBoss.attackBoss(address: self.owner!.address, amount: amount)
        }
        
        pub fun attackPlayer(enemyAddress: Address, amount: UFix64, perkIndex: Int?) {
          pre {
              SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
              SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
          }
          self.updatePlayer()
          SlothsEggsPvP.attackPlayer(address: self.owner!.address, enemyAddress: enemyAddress, amount: amount, perkIndex: perkIndex)
        }
        
        pub fun upgradeAttackPerkProducer(paymentVault: @FlowToken.Vault) {
          pre {
              SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
              SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
          }
          self.updatePlayer()
          SlothsEggsAttackPerks.upgradeAttackPerkProducer(address: self.owner!.address, paymentVault: <- paymentVault)
        }
        
        pub fun produceAttackPerk (index: Int) {
          pre {
              SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == false : "error.game.not.started.or.season.ended"
              SlothsEggs.roundPlayers.contains(self.owner!.address) == true: "error.not.registered.for.round"
          }
          self.updatePlayer()
          SlothsEggsAttackPerks.produceAttackPerk(address: self.owner!.address, index: index)
        }
        
        pub fun endRound() {
            pre {
                SlothsEggs.hasGameStarted() == true && SlothsEggs.hasSeasonEnded() == true : "error.game.not.started.or.season.ended"
            }
            self.updatePlayer()
            SlothsEggs.endRound(address: self.owner!.address)
        }
        
        pub fun distributeBudStakingPoolAndBurnBuds() {
          SlothsEggsBudStake.distributeBudStakingPoolAndBurnBuds(address: self.owner!.address)
        }


    }
    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.DEV_ADDRESS = self.account.address
        self.SEASION_DURATION = 86400.0 * 7.0 // 2 days
        self.GAME_START_TIME = getCurrentBlock().timestamp + (60.0 * 15.0) // 15 min after contract deploy
        
        self.lastSeasonStart = self.GAME_START_TIME
        self.roundPlayers = []
        self.userNames = {}
        SlothsEggsBushmen.setLastSeasonEnd(end: self.GAME_START_TIME)
        SlothsEggsSloths.setLastSeasonEnd(end:self.GAME_START_TIME)
        
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsAdmin)

        // Emit an event that shows that the contract was initialized
    }
}