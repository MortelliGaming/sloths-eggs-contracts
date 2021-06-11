
import SlothsEggsBud from 0xf90c7d67bb1e8145
import SlothsEggsPrizePools from 0xf90c7d67bb1e8145

pub contract SlothsEggsBudStake {

    pub event ContractInitialized()
    pub event BudStakeBurnt()
    pub event BudStakeAdded(address: Address, amount: UFix64)
    pub event PrizePoolDistributed(budStakeDistributedData: PrizePoolDsitributedData)
    pub let BUD_STAKE_PERIOD: UFix64
    pub var lastBudStakePayout: UFix64
    
    pub var playerBudStakes: {Address: UFix64}
    
    priv let budStakeVault: @SlothsEggsBud.Vault
    
    access(account) fun resetBudStakes() {
        self.playerBudStakes = {}
        destroy self.budStakeVault.withdraw(amount: self.budStakeVault.balance)
        self.lastBudStakePayout = getCurrentBlock().timestamp
        SlothsEggsPrizePools.dripFromReserve(topPlayerPoolPercent: 0.0, bossPoolPercent: 0.0, budStakingPoolPercent: 100.0, dripPercent: 5.0)
        emit BudStakeBurnt()
    }

    access(account) fun distributeBudStakingPoolAndBurnBuds(address: Address) {
      pre {
        getCurrentBlock().timestamp >= self.lastBudStakePayout + self.BUD_STAKE_PERIOD : "error.budstake.period.not.finished"
      }
      var eventData = PrizePoolDsitributedData(totalBudsBalance: 0.0, totalFlowBalance: 0.0, distributorFlowAmount: 0.0, playerBudStakes: {}, playerRewards: {})

      let budStakingPrizePoolRef = SlothsEggsPrizePools.getPrizeVaultReference(name: "budStakingPool")
      eventData.totalFlowBalance = budStakingPrizePoolRef.balance
      
      let totalBudsStaked = self.getBudStakeBalance()
      eventData.totalBudsBalance = totalBudsStaked
      
      if(budStakingPrizePoolRef.balance > 0.0) {
        // payout 5% of pool to player that run distribute tx
        let distributorAmount = budStakingPrizePoolRef.balance * 0.05
        let distributerFlowReceiverRef = SlothsEggsPrizePools.getAddressFlowReceiverReference(address: address)
        distributerFlowReceiverRef.deposit(from: <- budStakingPrizePoolRef.withdraw(amount: distributorAmount))
        eventData.distributorFlowAmount = distributorAmount
        // payout all stakers
        let playerBudStakes = self.playerBudStakes
        let totalBudStakeFlowBalance = budStakingPrizePoolRef.balance 
        for playerAddress in playerBudStakes.keys {
          let playerAmount = (totalBudStakeFlowBalance / totalBudsStaked).saturatingMultiply(playerBudStakes[playerAddress]!) 
          let playerFlowVaultRef = SlothsEggsPrizePools.getAddressFlowReceiverReference(address: playerAddress)
          playerFlowVaultRef.deposit(from: <- budStakingPrizePoolRef.withdraw(amount: playerAmount))!
          eventData.playerBudStakes[playerAddress] = playerBudStakes[playerAddress]!
          eventData.playerRewards[playerAddress] = playerAmount
        }
      }
      self.resetBudStakes()
      emit BudStakeBurnt()
      emit PrizePoolDistributed(budStakeDistributedData: eventData)
    }

    access(account) fun addPlayerBudStake(address: Address, amount: UFix64) {
      pre {
        getCurrentBlock().timestamp < self.lastBudStakePayout + self.BUD_STAKE_PERIOD : "error.budstake.period.finished"
        SlothsEggsBud.getPlayerVaultReference(address: address)!.balance >= amount : "error.not.enough.buds.to.stake"
      }
      if(self.playerBudStakes[address] == nil) {
        self.playerBudStakes[address] = 0.0
      }
      self.budStakeVault.deposit(from: <- SlothsEggsBud.getPlayerVaultReference(address: address)!.withdraw(amount: amount))
      self.playerBudStakes[address] = self.playerBudStakes[address]! + amount
      emit BudStakeAdded(address: address, amount: amount)
    }

    pub fun getBudStakeBalance(): UFix64 {
        return self.budStakeVault.balance
    }
    
    pub struct PrizePoolDsitributedData {
      pub(set) var totalBudsBalance: UFix64
      pub(set) var totalFlowBalance: UFix64
      pub(set) var distributorFlowAmount: UFix64
      pub(set) var playerBudStakes: {Address: UFix64}
      pub(set) var playerRewards: {Address: UFix64}

      init(totalBudsBalance: UFix64, totalFlowBalance: UFix64, distributorFlowAmount: UFix64, playerBudStakes: {Address: UFix64}, playerRewards: {Address: UFix64}) {
        self.totalBudsBalance = totalBudsBalance
        self.totalFlowBalance = totalFlowBalance
        self.distributorFlowAmount = distributorFlowAmount
        self.playerBudStakes = playerBudStakes
        self.playerRewards = playerRewards
      }
    }
    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.BUD_STAKE_PERIOD = 86400.0 // 1 day
        self.lastBudStakePayout = getCurrentBlock().timestamp
        self.playerBudStakes = {}
        self.budStakeVault <- SlothsEggsBud.createEmptyVault()
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsBudStakeAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsBudStakeAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}