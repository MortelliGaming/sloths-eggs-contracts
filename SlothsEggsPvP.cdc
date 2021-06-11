

import SlothsEggsBud from 0xf90c7d67bb1e8145
import SlothsEggsEgg from 0xf90c7d67bb1e8145
import SlothsEggsBushmen from 0xf90c7d67bb1e8145
import SlothsEggsSloths from 0xf90c7d67bb1e8145
import SlothsEggsAttackPerks from 0xf90c7d67bb1e8145
    

pub contract SlothsEggsPvP {

    pub event ContractInitialized()
    pub event PlayerAttacked(attackerAddress: Address, defenderAddress: Address, attackerEggs: UFix64, attackerPower: UFix64, defenderEggs: UFix64, defenderPower: UFix64, defenderRemainingEggs: UFix64 )
    pub event PlayerSummonedAttackersAndAttackedAgain(address: Address, defenderAddress: Address, newEnemyEggs: UFix64)
    pub event AttackerPowerChangeAdded(attackerAddress: Address, changedAmount: UFix64, isNegative: Bool)
    pub event DefenderPowerChangeAdded(defenderAddress: Address, changedAmount: UFix64, isNegative: Bool)
    
    pub let ATTACK_COOLDOWN_TIME: UFix64
    pub var playerLastAttackTimes: {Address: UFix64}
    pub var playerLastAttackedTimes: {Address: UFix64}
    

    priv fun resetPvP() {
        self.playerLastAttackTimes = {}
    }

    pub fun isPlayerCooldownOver(attackerAddress: Address): Bool {
      let lastAttack = self.playerLastAttackTimes[attackerAddress] != nil ? self.playerLastAttackTimes[attackerAddress]! : 0.0
      return lastAttack + self.ATTACK_COOLDOWN_TIME <= getCurrentBlock().timestamp
    }
    
    pub fun isDefenderCooldownOver(defenderAddress: Address): Bool {
      let lastAttack = self.playerLastAttackedTimes[defenderAddress] != nil ? self.playerLastAttackedTimes[defenderAddress]! : 0.0
      return lastAttack + self.ATTACK_COOLDOWN_TIME <= getCurrentBlock().timestamp
    }

    access(account) fun attackPlayer(address: Address, enemyAddress: Address, amount: UFix64, perkIndex: Int?) {
      pre {
        amount > 0.0 : "error.attack.with.no.eggs"
        self.isPlayerCooldownOver(attackerAddress: address) == true : "error.attack.in.cooldown"
        self.isDefenderCooldownOver(defenderAddress: enemyAddress) == true: "error.defender.in.cooldown"
      }
      SlothsEggsSloths.updatePlayer(address: address)
      SlothsEggsBushmen.updatePlayer(address: address)
      SlothsEggsSloths.updatePlayer(address: enemyAddress)
      SlothsEggsBushmen.updatePlayer(address: enemyAddress)
      if(SlothsEggsEgg.getPlayerBalance(address: address) < amount) {
        panic("error.not.enough.eggs.to.attack")
      }
      let playerEggVaultRef = SlothsEggsEgg.getPlayerVaultReference(address: address)!
      let enemyEggVaultRef = SlothsEggsEgg.getPlayerVaultReference(address: enemyAddress)!
      if(enemyEggVaultRef.balance < playerEggVaultRef.balance) {
        let attackEggsToEnemyBalancePercent = (100.0 / SlothsEggsEgg.getPlayerBalance(address: enemyAddress)).saturatingMultiply(amount)
        if(attackEggsToEnemyBalancePercent > 200.0) {
          panic("error.attack.with.no.more.than.200.percent.of.enemy.eggsBalance")
        }
      }

      var attackerPower = amount
      var defenderPower = enemyEggVaultRef.balance
      // use perk with index 0 and 3
      // 0: (add 10% attacker)
      // 3: (kill 5% of enemy)
      if(perkIndex != nil) {
        if(perkIndex! == 0 || perkIndex! == 3)  {
          let perkResult = SlothsEggsAttackPerks.useAttackPerk(address: address, perkIndex: perkIndex!, attackerPower: amount, defenderPower: enemyEggVaultRef.balance)
          attackerPower = perkResult.attackerPower
          defenderPower = perkResult.defenderPower
        }
      }

      let attackerBoost = self.getRandomNumber(max: 15 as UInt64)
      let isAttackerBoostNegative = self.getRandomBoolWithModulo(modulo: 10 as UInt64) // 10% chance
      let enemyBoost = self.getRandomNumber(max: 20 as UInt64)
      let isEnemyBoostNegative = self.getRandomBoolWithModulo(modulo: 5 as UInt64) // 20% chance

      attackerPower = isAttackerBoostNegative == true ? attackerPower.saturatingSubtract(attackerPower / 100.0 * UFix64(attackerBoost)) : attackerPower.saturatingAdd(attackerPower / 100.0 * UFix64(attackerBoost))
      defenderPower = isEnemyBoostNegative == true ? defenderPower.saturatingSubtract(defenderPower / 100.0 * UFix64(enemyBoost)) : defenderPower.saturatingAdd(defenderPower / 100.0 * UFix64(enemyBoost))
      
      emit AttackerPowerChangeAdded(attackerAddress: address, changedAmount: attackerPower / 100.0 * UFix64(attackerBoost), isNegative: isAttackerBoostNegative)
      emit DefenderPowerChangeAdded(defenderAddress: enemyAddress, changedAmount: defenderPower / 100.0 * UFix64(enemyBoost), isNegative: isEnemyBoostNegative)
      // use perk 2 (add 20% damage)
      if(perkIndex != nil) {
        if(perkIndex! == 2)  {
          let perkResult = SlothsEggsAttackPerks.useAttackPerk(address: address, perkIndex: perkIndex!, attackerPower: attackerPower, defenderPower: defenderPower)
          attackerPower = perkResult.attackerPower
          defenderPower = perkResult.defenderPower
        }
      }
      emit PlayerAttacked(attackerAddress: address, defenderAddress: enemyAddress, attackerEggs: amount, attackerPower: attackerPower, defenderEggs: enemyEggVaultRef.balance, defenderPower: defenderPower, defenderRemainingEggs: defenderPower.saturatingSubtract(attackerPower) )
      defenderPower = defenderPower.saturatingSubtract(attackerPower)
      
      // use perk 1 (summon 15% of attackers)
      if(perkIndex != nil) {
        if(perkIndex! == 1)  {
          let perkResult = SlothsEggsAttackPerks.useAttackPerk(address: address, perkIndex: perkIndex!, attackerPower: attackerPower, defenderPower: defenderPower)
          attackerPower = perkResult.attackerPower
          defenderPower = perkResult.defenderPower
          defenderPower = defenderPower.saturatingSubtract(attackerPower)
          emit PlayerSummonedAttackersAndAttackedAgain(address: address, defenderAddress: enemyAddress, newEnemyEggs: defenderPower)
        }
      }
      
      if(defenderPower == 0.0) {
        let playerBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: address)!
        let enemyBudVaultRef = SlothsEggsBud.getPlayerVaultReference(address: enemyAddress)!
        var stealPercent = UFix64(self.getRandomNumber(max: 40 as UInt64)) + 10.0
        playerBudVaultRef.deposit(from: <- enemyBudVaultRef.withdraw(amount: enemyBudVaultRef.balance / 100.0 * stealPercent))
      }
      destroy enemyEggVaultRef.withdraw(amount: enemyEggVaultRef.balance.saturatingSubtract(defenderPower))
      destroy playerEggVaultRef.withdraw(amount: amount)
      self.playerLastAttackTimes[address] = getCurrentBlock().timestamp
      self.playerLastAttackedTimes[enemyAddress] = getCurrentBlock().timestamp
    }

    pub fun getRandomNumber(max: UInt64): UInt64 {
      let random = unsafeRandom()
      let rangeWidth = UInt64.max / max
      return random / rangeWidth
    }

    // %5 is 20% (each 5th number has %5 == 0)
    pub fun getRandomBoolWithModulo(modulo: UInt64): Bool {
      let random = unsafeRandom()
      return random % modulo == 0 as UInt64
    }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.ATTACK_COOLDOWN_TIME = 60.0 * 15.0 // 15 minutes
        self.playerLastAttackTimes = {}
        self.playerLastAttackedTimes = {}
        
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsPvPAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsPvPAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}