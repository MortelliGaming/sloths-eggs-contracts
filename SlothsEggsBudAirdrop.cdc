import SlothsEggsBud from 0xf90c7d67bb1e8145

pub contract SlothsEggsBudAirdrop {

    pub event ContractInitialized()
    pub event AirdropClaimed(address: Address, amount: UFix64)
    pub event AirdropBonusClaimed(address: Address, amount: UFix64)

    pub let AIRDROP_BUD_AMOUNT: UFix64
    pub let AIRDROP_CLAIM_INTERVAL: UFix64
    pub var lastAirdropStart: UFix64

    pub var playerClaimTimes: { Address: UFix64 }
    pub var playerContinoousClaimCount: { Address: Int }
    

    priv fun updateAirdropTimes() {
        if(self.lastAirdropStart + self.AIRDROP_CLAIM_INTERVAL <= getCurrentBlock().timestamp){
            self.lastAirdropStart = self.lastAirdropStart + self.AIRDROP_CLAIM_INTERVAL
            self.updateAirdropTimes()
        }
    }
    
    access(account) fun initPlayer(address: Address) {
        self.playerClaimTimes[address] = 0.0
        self.playerContinoousClaimCount[address] = 0
    }
    
    access(account) fun claimBudAirdrop(address: Address) {
        self.updateAirdropTimes()
        if(self.lastAirdropStart < self.playerClaimTimes[address]!) {
          panic( "error.airdrop.already.claimed")
        }
        if(self.playerClaimTimes[address] == nil){
          self.playerClaimTimes[address] = 0.0
          self.playerContinoousClaimCount[address] = 0
        }
        

        SlothsEggsBud.mintTokensForPlayer(amount: self.AIRDROP_BUD_AMOUNT, playerAddress: address)
        if(getCurrentBlock().timestamp - self.playerClaimTimes[address]! < self.AIRDROP_CLAIM_INTERVAL) {
            self.playerContinoousClaimCount[address] = self.playerContinoousClaimCount[address]! + 1
        } else {
            self.playerContinoousClaimCount[address] = 1
        }
        emit AirdropClaimed(address: address, amount: self.AIRDROP_BUD_AMOUNT)
        if(self.playerContinoousClaimCount[address] ==  7) {
            SlothsEggsBud.mintTokensForPlayer(amount: self.AIRDROP_BUD_AMOUNT * 100.0, playerAddress: address)
            self.playerContinoousClaimCount[address] = 0
            emit AirdropBonusClaimed(address: address, amount: self.AIRDROP_BUD_AMOUNT * 100.0)
        }
        self.playerClaimTimes[address] = getCurrentBlock().timestamp
    }

    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        
    }
    
    init() {
        self.AIRDROP_BUD_AMOUNT= 500.0
        self.AIRDROP_CLAIM_INTERVAL= 86400.0 / 24.0
        self.lastAirdropStart= getCurrentBlock().timestamp

        self.playerClaimTimes= {}
        self.playerContinoousClaimCount= {}

        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsBudAirdropAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsBudAirdropAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit ContractInitialized()
    }
}