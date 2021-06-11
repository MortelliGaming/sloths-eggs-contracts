
import FlowToken from 0x7e60df042a9c0868
import FungibleToken from 0x9a0766d93b6608b7
import SlothsEggsSponsor from 0xf90c7d67bb1e8145


pub contract SlothsEggsPrizePools {

    pub event DepositedToReserveVault(amount: UFix64)
    pub event DepositedToBossKillPool(amount: UFix64)
    pub event DepositedToBudStakingPool(amount: UFix64)
    pub event DepositedToTopBudProductionPool(amount: UFix64)
    pub event PrizePoolAdded(name: String)

    pub let DEV_ADDRESS: Address

    access(contract) var prizeVaults: @{ String: FlowToken.Vault }
    access(contract) var reserveVault: @FlowToken.Vault
    

    access(account) fun getAddressFlowReceiverReference(address: Address): &FlowToken.Vault{FungibleToken.Receiver} {
      let flowVaultRef = getAccount(address)
        .getCapability(/public/flowTokenReceiver)!
        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
      return flowVaultRef!
    }

    access(account) fun distributeToDevAndSponsorAndReserveVault(paymentVault: @FlowToken.Vault) {
      let devRef = self.getAddressFlowReceiverReference(address: self.DEV_ADDRESS)
      let gameSponsorRef = self.getAddressFlowReceiverReference(address: SlothsEggsSponsor.currentGameSponsorAddresses["gameSponsor"]!)
      let paymentAmount = paymentVault.balance
      let devFeeAmount = paymentAmount / 100.0 * 5.0
      let sponsorFeeAmount = paymentAmount / 100.0 * 5.0

      gameSponsorRef.deposit(from: <- paymentVault.withdraw(amount: sponsorFeeAmount))
      devRef.deposit(from: <- paymentVault.withdraw(amount: devFeeAmount))
      let depositAmount = paymentVault.balance
      self.reserveVault.deposit(from: <- paymentVault)
      emit DepositedToReserveVault(amount: depositAmount)
    }

    access(account) fun dripFromReserve(topPlayerPoolPercent: UFix64, bossPoolPercent: UFix64, budStakingPoolPercent: UFix64, dripPercent: UFix64) {
        pre {
            topPlayerPoolPercent + bossPoolPercent + budStakingPoolPercent == 100.0 : "error.splitpercentage.not.100"
        }
        let dripAmount = self.reserveVault.balance / 100.0 * dripPercent // 5% of the reserve drips to pricepools  
        self.prizeVaults["topBudProductionPool"]?.deposit(from: <- self.reserveVault.withdraw(amount: dripAmount / 100.0 * topPlayerPoolPercent ))
        emit DepositedToTopBudProductionPool(amount: dripAmount / 100.0 * topPlayerPoolPercent)
        self.prizeVaults["bossKillPool"]?.deposit(from: <- self.reserveVault.withdraw(amount: dripAmount / 100.0 * bossPoolPercent))
        emit DepositedToBossKillPool(amount: dripAmount  / 100.0 * bossPoolPercent)
        self.prizeVaults["budStakingPool"]?.deposit(from: <- self.reserveVault.withdraw(amount: dripAmount / 100.0 * budStakingPoolPercent))
        emit DepositedToBudStakingPool(amount: dripAmount  / 100.0 * budStakingPoolPercent)
    }
    
    access(account) fun getPrizeVaultReference(name: String): &FlowToken.Vault {
        pre {
            self.prizeVaults.keys.contains(name): "error.invalid.prizeVaultName"
        }
        return &self.prizeVaults[name] as! &FlowToken.Vault
    }

    pub fun getPrizeVaultBalance(name: String): UFix64 {
        pre {
            self.prizeVaults.keys.contains(name): "error.invalid.prizeVaultName"
        }
        return self.prizeVaults[name]?.balance!
    }
    
    pub fun getPrizeVaultNames(): [String] {
        return self.prizeVaults.keys
    }

    pub fun getReserveVaultBalance(): UFix64 {
        return self.reserveVault.balance
    }
    
    pub resource Administrator {
        pub fun addNewPricePool(name: String) {
            pre {
                SlothsEggsPrizePools.prizeVaults[name] == nil : "error.prizepool.already.exists"
            }
            SlothsEggsPrizePools.prizeVaults[name] <-! (FlowToken.createEmptyVault() as! @FlowToken.Vault)
            emit PrizePoolAdded(name: name)
        }
    }
    
    init() {
        self.DEV_ADDRESS = self.account.address
        
        self.prizeVaults <- {
            "topBudProductionPool": <- (FlowToken.createEmptyVault() as! @FlowToken.Vault),
            "bossKillPool": <- (FlowToken.createEmptyVault() as! @FlowToken.Vault),
            "budStakingPool": <- (FlowToken.createEmptyVault() as! @FlowToken.Vault)
        }
        self.reserveVault <- (FlowToken.createEmptyVault() as! @FlowToken.Vault)
        
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsPrizePoolsAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsPrizePoolsAdmin)

        // Emit an event that shows that the contract was initialized
    }
}