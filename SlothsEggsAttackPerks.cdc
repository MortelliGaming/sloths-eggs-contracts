import FlowToken from 0x7e60df042a9c0868
import FungibleToken from 0x9a0766d93b6608b7

import SlothsEggsPrizePools from 0xf90c7d67bb1e8145
import SlothsEggsBud from 0xf90c7d67bb1e8145

access(all) contract SlothsEggsAttackPerks {
    // events
    pub event AttackPerkProducerUpgraded(address: Address, newLevel: Int)
    pub event AttackPerkProduced(address: Address, index: Int)
    pub event PerkUsed(attatckerAddress: Address, attackerPowerBefore: UFix64, attackerPowerAfter: UFix64, defenderPowerBefore: UFix64, defenderPowerAfter: UFix64)
    
    /*
    * Booster
    */
    // the types of boosters (index is level)
    pub let attackPerkTypes: { Int: AttackPerkType }
    // the levels of the producer (cost, upgradetime,...)
    pub let attackPerkProducerLevels: { Int: AttackPerkProducerLevel }

    // store the players AttackPerk producer level
    pub var playerAttackPerkProducerLevels: { Address: Int }
    // store the players start of upgrade of the AttackPerkerproducer
    pub var playerAttackPerkProducerUpgradeEndTimes: { Address: UFix64 }
    // store the players AttackPerkers amount index0-lvl1, index1-lvl2...lvl4
    pub var playerAttackPerk: { Address: [Int; 4] }
    // store the players AttackPerker production start times
    pub var playerAttackPerkProductionEndTimes: { Address: [UFix64; 4] }
    
    init() {
        /********
        * Attack Boosters *
        *********/
        // store perk production levels (upgradetime, costs,...)
        self.attackPerkProducerLevels = { 
          0: AttackPerkProducerLevel(budsCost: 1000.0 as UFix64, flowCost: 0.0, upgradeTime: 60.0 * 5.0 /* 5 minutes */),
          1: AttackPerkProducerLevel(budsCost: 10000.0 as UFix64, flowCost: 0.1, upgradeTime: 60.0 * 15.0 /* 15 minutes */),
          2: AttackPerkProducerLevel(budsCost: 100000.0 as UFix64, flowCost: 0.5, upgradeTime: 60.0 * 60.0 /* 60 minutes */),
          3: AttackPerkProducerLevel(budsCost: 1000000.0 as UFix64, flowCost: 1.0, upgradeTime: 60.0 * 240.0 /* 240 minutes */),
          4: AttackPerkProducerLevel(budsCost: 0.0 as UFix64, flowCost: 0.0, upgradeTime: 0.0 /* 240 minutes */)
        }
        // store perk types
        self.attackPerkTypes = { 
          0: AttackPerkType(budCost: 5000.0, productionTime: 60.0 * 5.0 /* 5 minutes */, requiredProducerLevel: 1, attackBoostPercent: 10 as UInt, limit: 10),
          1: AttackPerkType(budCost: 50000.0, productionTime: 60.0 * 15.0 /* 15 minutes */, requiredProducerLevel: 2, attackBoostPercent: 15 as UInt, limit: 2),
          2: AttackPerkType(budCost: 500000.0, productionTime: 60.0 * 30.0 /* 30 minutes */, requiredProducerLevel: 3, attackBoostPercent: 20 as UInt, limit: 4),
          3: AttackPerkType(budCost: 5000000.0, productionTime: 60.0 * 60.0 /* 60 minutes */, requiredProducerLevel: 4, attackBoostPercent: 0 as UInt, limit: 8)
        }
        
        self.playerAttackPerkProducerLevels = {}
        self.playerAttackPerkProducerUpgradeEndTimes = {}
        self.playerAttackPerk = {}
        self.playerAttackPerkProductionEndTimes = {}


        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsAttackPerksAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsAttackPerksAdmin)
    }
    
    pub fun effectivePlayerPerkProducerLevels(): {Address: Int} {
      var effectivePlayerLevels: {Address: Int} = {}
      for playerAddress in self.playerAttackPerkProducerLevels.keys {
        effectivePlayerLevels[playerAddress] = self.getPlayerAttackPerkProducerLevel(address: playerAddress)
        if(self.playerAttackPerkProducerUpgradeEndTimes[playerAddress]! != 0.0) {
          if(self.playerAttackPerkProducerUpgradeEndTimes[playerAddress]! < getCurrentBlock().timestamp) {
            effectivePlayerLevels[playerAddress] = effectivePlayerLevels[playerAddress]! + 1
          }
        } 
      }
      return effectivePlayerLevels
    }
    
    pub fun effectivePlayerAttackPerks(): {Address: [Int; 4]} {
      var effectivePlayerAttackPerks: {Address:  [Int; 4]} = {}
      for playerAddress in self.playerAttackPerkProducerLevels.keys {
        effectivePlayerAttackPerks[playerAddress] = self.getPlayerAttackPerkCount(address: playerAddress)
        var perkCountIndex = 0
        while perkCountIndex < effectivePlayerAttackPerks[playerAddress]!.length {
          if(self.playerAttackPerkProductionEndTimes[playerAddress]![perkCountIndex] != 0.0) {
            if(self.playerAttackPerkProductionEndTimes[playerAddress]![perkCountIndex] < getCurrentBlock().timestamp) {
              var oldCount = effectivePlayerAttackPerks[playerAddress]!
              oldCount[perkCountIndex] = oldCount[perkCountIndex]! + 1
              effectivePlayerAttackPerks[playerAddress] = oldCount
            }
          }
          perkCountIndex = perkCountIndex + 1
        }
         
      }
      return effectivePlayerAttackPerks
    }

    priv fun getPlayerAttackPerkProducerLevel(address: Address): Int {
      return (self.playerAttackPerkProducerLevels[address] != nil ? self.playerAttackPerkProducerLevels[address]! : 0)
    }

    priv fun getPlayerAttackPerkCount(address: Address): [Int; 4] {
      return (self.playerAttackPerk[address] != nil ? self.playerAttackPerk[address]! : [0,0,0,0] as [Int;4])
    }

    pub fun isAttackPerkProducerUpgrading(address: Address): Bool {
      let lastStart = self.playerAttackPerkProducerUpgradeEndTimes[address]!
      if(lastStart == 0.0) {
        return false
      }
      let currentAttackPerkProducerLevel = self.playerAttackPerkProducerLevels[address]!
      let upgradeTime = self.attackPerkProducerLevels[currentAttackPerkProducerLevel]!.upgradeTime
      if(lastStart + upgradeTime < getCurrentBlock().timestamp) {
        return false
      }
      return true
    }

    pub fun isAttackPerkProducing(address: Address, index: Int): Bool {
      let productionEndTime = self.playerAttackPerkProductionEndTimes[address]![index]
      if(productionEndTime == 0.0) {
        return false
      }
      if(productionEndTime < getCurrentBlock().timestamp) {
        return false
      }
      return true
    }

    access(account) fun initPlayer(address: Address) {
      self.playerAttackPerkProducerLevels[address] = 0
      self.playerAttackPerkProducerUpgradeEndTimes[address] = 0.0
      self.playerAttackPerk[address] = [0,0,0,0] as [Int;4]
      self.playerAttackPerkProductionEndTimes[address] = [0.0,0.0,0.0,0.0] as [UFix64;4]
    }

    access(account) fun updatePlayer(address: Address) {
      // update attack booster producer level
      if(self.playerAttackPerkProducerLevels[address] == nil) {
        self.initPlayer(address: address)
      }
      let upgradeEndTime = self.playerAttackPerkProducerUpgradeEndTimes[address]!
      if(upgradeEndTime != 0.0 && upgradeEndTime < getCurrentBlock().timestamp) {
        self.playerAttackPerkProducerLevels[address] = self.playerAttackPerkProducerLevels[address]! + 1
        self.playerAttackPerkProducerUpgradeEndTimes[address] = 0.0
      }
      // update attack booster counts
      let updatedCounts = self.playerAttackPerk[address]!
      let updatedTimes = self.playerAttackPerkProductionEndTimes[address]!
      for attackPerkIndex in self.attackPerkTypes.keys {
        let productionEndTime = self.playerAttackPerkProductionEndTimes[address]![attackPerkIndex]!
        if(productionEndTime != 0.0 && productionEndTime < getCurrentBlock().timestamp) {
          updatedCounts[attackPerkIndex] = self.playerAttackPerk[address]![attackPerkIndex] + 1
          updatedTimes[attackPerkIndex] = 0.0
        }
      }
      self.playerAttackPerk[address] = updatedCounts
      self.playerAttackPerkProductionEndTimes[address] = updatedTimes
    }

    access(account) fun upgradeAttackPerkProducer (address: Address, paymentVault: @FlowToken.Vault) {
        pre {
            (self.effectivePlayerPerkProducerLevels()[address] != nil ? self.effectivePlayerPerkProducerLevels()[address]! : 0)! < (self.attackPerkProducerLevels.keys.length - 1) : "error.attackperkproducer.maxlevel.reached"
            paymentVault.balance >= self.attackPerkProducerLevels[self.effectivePlayerPerkProducerLevels()[address] != nil ? self.effectivePlayerPerkProducerLevels()[address]! : 0]!.flowCost : "error.flow.payment.too.low"
        }
        self.updatePlayer(address: address)
        if(self.isAttackPerkProducerUpgrading(address: address) == true) {
            panic("error.already.upgrading.attackPerkProducer")
        }
        if(paymentVault.balance > 0.0) {
          SlothsEggsPrizePools.distributeToDevAndSponsorAndReserveVault(paymentVault: <- paymentVault)
          SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 33.0, bossPoolPercent: 33.0, budStakingPoolPercent: 34.0, dripPercent: 0.05)
        }
        let budsCost = self.attackPerkProducerLevels[self.effectivePlayerPerkProducerLevels()[address]!]!.budsCost
        
        let playerBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        if(budsCost > playerBudVaultRef.balance) {
          panic("error.not.enough.buds")
        }
        destroy playerBudVaultRef!.withdraw(amount: budsCost)
        self.playerAttackPerkProducerUpgradeEndTimes[address] = getCurrentBlock().timestamp + self.attackPerkProducerLevels[self.playerAttackPerkProducerLevels[address]!]!.upgradeTime
    }

    access(account) fun produceAttackPerk (address: Address, index: Int) {
        self.updatePlayer(address: address)
        if(self.isAttackPerkProducing(address: address, index: index) == true) {
            panic("error.already.producing.attackPerk")
        }
        if(self.playerAttackPerkProducerLevels[address]! < self.attackPerkTypes[index]!.requiredProducerLevel) {
            panic("error.attackPerk.attackboostproducer.level.too.low")
        }
        if(self.playerAttackPerk[address]![index]! >= self.attackPerkTypes[index]!.limit) {
            panic("error.attackPerk.limit.reached")
        }
        
        let budsCost = self.attackPerkTypes[index]!.budCost
        
        let playerBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        if(budsCost > playerBudVaultRef.balance) {
          panic("error.not.enough.buds")
        }
        destroy playerBudVaultRef!.withdraw(amount: budsCost)
        
        let updatedTimes = self.playerAttackPerkProductionEndTimes[address]!
        updatedTimes[index] = getCurrentBlock().timestamp + self.attackPerkTypes[index]!.productionTime
        self.playerAttackPerkProductionEndTimes[address] = updatedTimes
    }

    pub struct AttackPerkResult {
        pub(set) var attackerPower: UFix64
        pub(set) var defenderPower: UFix64

        init(attackerPower: UFix64, defenderPower: UFix64) {
            self.attackerPower = attackerPower
            self.defenderPower = defenderPower
        }
    }

    access(account) fun useAttackPerk(address: Address, perkIndex: Int, attackerPower: UFix64, defenderPower: UFix64): AttackPerkResult {
        pre {
            perkIndex < self.attackPerkTypes.keys.length : "error.invalid.perkIndex"
        }
        self.updatePlayer(address: address)
        if(self.playerAttackPerk[address]![perkIndex] < 1) {
            panic("error.no.attackperk.available")
        }
        let oldAttackPerkCount = self.playerAttackPerk[address]!
        oldAttackPerkCount[perkIndex] = oldAttackPerkCount[perkIndex] - 1
        self.playerAttackPerk[address] = oldAttackPerkCount
        let perkResult = self.calculatePerkResult(perkIndex: perkIndex, attackerPower: attackerPower, defenderPower: defenderPower)
        emit PerkUsed(attatckerAddress: address, attackerPowerBefore: attackerPower, attackerPowerAfter: perkResult.attackerPower, defenderPowerBefore: defenderPower, defenderPowerAfter: perkResult.defenderPower)
        return perkResult
    }

    access(contract) fun calculatePerkResult(perkIndex: Int, attackerPower: UFix64, defenderPower: UFix64): AttackPerkResult {
        var perkResult = AttackPerkResult(attackerPower: attackerPower, defenderPower: defenderPower)
        if(perkIndex == 0) {
            // should be added before calculating total attacks
            perkResult.attackerPower = perkResult.attackerPower.saturatingAdd((perkResult.attackerPower / 100.0).saturatingMultiply(10.0))
        }
        if(perkIndex == 1) {
            // post attack perk - attackerpower should be attackerpower of start
            perkResult.attackerPower = (perkResult.attackerPower / 100.0).saturatingMultiply(15.0)
        }
        if(perkIndex == 2) {
            // should be added after calculating total attack
            perkResult.attackerPower = perkResult.attackerPower.saturatingAdd((perkResult.attackerPower / 100.0).saturatingMultiply(20.0))
        }
        if(perkIndex == 3) {
            // should be added before calculating total attacks
            perkResult.defenderPower = perkResult.defenderPower.saturatingSubtract((perkResult.defenderPower / 100.0).saturatingMultiply(5.0))
        }
        return perkResult
    }

    pub struct AttackPerkType {
      pub let budCost: UFix64
      pub let productionTime: UFix64
      pub let requiredProducerLevel: Int
      pub let attackBoostPercent: UInt
      pub let limit: Int
      
      init(budCost: UFix64, productionTime: UFix64, requiredProducerLevel: Int, attackBoostPercent: UInt, limit: Int) {
        self.budCost = budCost
        self.productionTime = productionTime
        self.requiredProducerLevel = requiredProducerLevel
        self.attackBoostPercent = attackBoostPercent
        self.limit = limit
      }
    }

    pub struct AttackPerkProducerLevel {
      pub let budsCost: UFix64
      pub let flowCost: UFix64
      pub let upgradeTime: UFix64
      
      init(budsCost: UFix64, flowCost: UFix64, upgradeTime: UFix64) {
        self.budsCost = budsCost
        self.flowCost = flowCost
        self.upgradeTime = upgradeTime
      }
    }

    pub resource Administrator {
        
    }
}