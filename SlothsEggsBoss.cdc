import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

import SlothsEggsEgg from 0xf90c7d67bb1e8145
import SlothsEggsPvP from 0xf90c7d67bb1e8145
import SlothsEggsBushmen from 0xf90c7d67bb1e8145
import SlothsEggsPrizePools from 0xf90c7d67bb1e8145

pub contract SlothsEggsBoss {

    pub event ContractInitialized()
    pub event BossAttacked(address: Address, buds: UFix64, power: UFix64)
    pub event BossAttackedByPlayer(address: Address, playerEggs: UFix64, playerPower: UFix64, bossPower: UFix64, bossRemainingHP: UFix64)
    pub event BossKilled(address: Address)
    pub event PlayerPaymentFromBudBossKillPool(address: Address, amount: UFix64)
  
    pub let ATTACK_COOLDOWN_TIME: UFix64
    pub var playerAttackTimes: {Address: UFix64}
    pub var bossCurrentHP: UFix64
    pub var bossFullHP: UFix64
    pub var playerDamagePoints: {Address: UFix64}
    
    priv fun getAddressFlowReceiverReference(address: Address): &FlowToken.Vault{FungibleToken.Receiver} {
      let flowVaultRef = getAccount(address)
        .getCapability(/public/flowTokenReceiver)!
        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
      return flowVaultRef!
    }

    priv fun resetBoss() {
        self.bossFullHP = self.bossFullHP.saturatingMultiply(2.0)
        self.bossCurrentHP = self.bossFullHP
        self.playerDamagePoints = {}
    }

    access(account) fun attackBoss(address: Address, amount: UFix64) {
      pre {
        SlothsEggsEgg.getPlayerVaultReference(address: address)!.balance >= amount : "error.not.enough.eggs.to.attack"
        (self.playerAttackTimes[address] != nil ? self.playerAttackTimes[address]!: 0.0) + self.ATTACK_COOLDOWN_TIME <= getCurrentBlock().timestamp: "error.bossattack.on.cooldown"
      }
      if(self.playerDamagePoints[address] == nil) {
        self.playerDamagePoints[address] = 0.0
      }
      destroy SlothsEggsEgg.getPlayerVaultReference(address: address)!.withdraw(amount: amount)
      
      var initialAttackPower = amount
      var initialDefensePower = self.bossCurrentHP
      
      var bonusPercentPlayer = UFix64(SlothsEggsPvP.getRandomNumber(max: 15))
      var isPlayerBonusNegative = SlothsEggsPvP.getRandomBoolWithModulo(modulo: 5) // 20%
      var playerBonusAmount = (initialAttackPower / 100.0).saturatingMultiply(bonusPercentPlayer)
      
      var bonusPercentBoss = UFix64(SlothsEggsPvP.getRandomNumber(max: 20))
      var isBossBonusNegative = SlothsEggsPvP.getRandomBoolWithModulo(modulo: 3) // 33.3%
      var bossBonusAmount = (self.bossCurrentHP / 100.0).saturatingMultiply(bonusPercentBoss)
      
      var playerAttackPower = isPlayerBonusNegative == true ? initialAttackPower.saturatingSubtract(playerBonusAmount) : initialAttackPower.saturatingAdd(playerBonusAmount)
      var bossDefensePower = isBossBonusNegative == true ? initialDefensePower.saturatingSubtract(bossBonusAmount) : initialDefensePower.saturatingAdd(bossBonusAmount)
      
      var attackPower = (bossDefensePower > playerAttackPower ? playerAttackPower: bossDefensePower)
      var remainingPower = bossDefensePower - attackPower
      
      self.playerDamagePoints[address] = self.playerDamagePoints[address]!.saturatingAdd(attackPower)
      self.playerAttackTimes[address] = getCurrentBlock().timestamp
      self.bossCurrentHP = remainingPower
      
      emit BossAttackedByPlayer(address: address, playerEggs: amount, playerPower: attackPower, bossPower: bossDefensePower, bossRemainingHP: self.bossCurrentHP)
      emit BossAttacked(address: address, buds: amount, power: attackPower)
      if(self.bossCurrentHP == 0.0) {
        self.handleBossKill(killerAddress: address)
        self.resetBoss()
      } else {
        /*var bushmanIndex = SlothsEggsPvP.getRandomNumber(max: 6)
        var bossKillBushman = SlothsEggsPvP.getRandomBoolWithModulo(modulo: 10)
        if(bossKillBushman == true) {
          SlothsEggsBushmen.decreasePlayerBushmanLevel(address: address, index: Int(bushmanIndex) + 1)
        }*/ 
      }
    }
    priv fun getTotalDamage(): UFix64 {
      var totalDamage = 0.0
      for damageAddress in self.playerDamagePoints.keys {
        totalDamage = totalDamage + self.playerDamagePoints[damageAddress]! 
      }
      return totalDamage
    }
    priv fun handleBossKill(killerAddress: Address) {
      // killer gets 10% 
      let bossPoolRef = SlothsEggsPrizePools.getPrizeVaultReference(name: "bossKillPool")!
      if(bossPoolRef.balance > 0.0) {
        let killerAmount = (bossPoolRef.balance / 100.0).saturatingMultiply(10.0)
        self.getAddressFlowReceiverReference(address: killerAddress).deposit(from: <- bossPoolRef.withdraw(amount: killerAmount))
        emit PlayerPaymentFromBudBossKillPool(address: killerAddress, amount: killerAmount)
        // rest distributed proportional to damage (also last attacker gets his part!)
        let totalBossPoolBalance = bossPoolRef.balance
        let totalDamage = self.getTotalDamage()
        for damageAddress in self.playerDamagePoints.keys {
          let playerAmount = totalBossPoolBalance / totalDamage * self.playerDamagePoints[damageAddress]!
          self.getAddressFlowReceiverReference(address: damageAddress).deposit(from: <- bossPoolRef.withdraw(amount: playerAmount))
          emit PlayerPaymentFromBudBossKillPool(address: damageAddress, amount: playerAmount)
        }
      }
      
      SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 0.0, bossPoolPercent: 100.0, budStakingPoolPercent: 0.0, dripPercent: 5.0)
      emit BossKilled(address: killerAddress)
    }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.ATTACK_COOLDOWN_TIME = 86400.0 / 24.0 / 6.0 // 10 minutes
        self.playerAttackTimes = {}
        self.bossFullHP = 100.0
        self.bossCurrentHP = 100.0
        self.playerDamagePoints = {}
        
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsBossAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsBossAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}