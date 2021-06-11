import FungibleToken from 0x9a0766d93b6608b7

pub contract SlothsEggsEgg: FungibleToken {

    /// Total supply of SlothsEggsEggs in existence
    pub var totalSupply: UFix64
    
    /// private playerVaults
    priv let playerVaults: @{Address: Vault}
    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)
    
    pub event TokensBurnt(amount: UFix64)
    
    pub event TokensMinted(amount: UFix64)
    /// Vault
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        /// The total balance of this vault
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount <= self.balance: "error.funds.too.low"
            }
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <- (create Vault(balance: amount))
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @SlothsEggsEgg.Vault
            var oldAmount = self.balance
            self.balance = self.balance.saturatingAdd(vault.balance)
            emit TokensDeposited(amount: self.balance - oldAmount, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if(self.balance > 0.0) {
              emit TokensBurnt(amount: self.balance)
              SlothsEggsEgg.totalSupply = SlothsEggsEgg.totalSupply.saturatingSubtract(self.balance)
            }
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    pub fun createEmptyVault(): @Vault {
        return <- create Vault(balance: 0.0)
    }
    
    /// getPlayerBalance
    ///
    /// Function that returns the balance of the Vault stored for an Address
    pub fun getPlayerBalance(address: Address): UFix64 {
      return self.playerVaults[address] != nil ? self.playerVaults[address]?.balance! : 0.0
    }

    /// creates an empty vault stored on contract for an address (account only!)
    access(account) fun createPlayerVault(address: Address) {
      if(self.playerVaults[address] == nil) {
        self.playerVaults[address] <-! self.createEmptyVault()
      }
    }
    
    /// gets the reference to an addresses vault (contract stored) (account only)
    access(account) fun getPlayerVaultReference(address: Address):&Vault? {
      if(self.playerVaults[address] == nil) {
        return nil
      }
      return &self.playerVaults[address] as! auth &Vault
    }
    
    /// mints tokens and deposits on the players vault (on contract) 
    access(account) fun mintTokensForPlayer(amount: UFix64, playerAddress: Address) {
        pre {
            amount > 0.0: "Amount minted must be greater than zero"
        }
        if(self.playerVaults[playerAddress] == nil){
          self.playerVaults[playerAddress] <-! self.createEmptyVault()
        }
        var oldAmount = SlothsEggsEgg.totalSupply
        SlothsEggsEgg.totalSupply = SlothsEggsEgg.totalSupply.saturatingAdd(amount)
        emit TokensMinted(amount: SlothsEggsEgg.totalSupply - oldAmount)
        var newVault <- create Vault(balance: SlothsEggsEgg.totalSupply - oldAmount)
        self.playerVaults[playerAddress]?.deposit(from: <- newVault.withdraw(amount: newVault.balance))
        destroy newVault
    }
    
    /// the admin can mint tokens outside of the game
    pub resource Administrator {
        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        pub fun mintTokens(amount: UFix64): @SlothsEggsEgg.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
            }
            var oldAmount = SlothsEggsEgg.totalSupply
            SlothsEggsEgg.totalSupply = SlothsEggsEgg.totalSupply.saturatingAdd(amount)
            emit TokensMinted(amount: SlothsEggsEgg.totalSupply - oldAmount)
            return <-create Vault(balance: SlothsEggsEgg.totalSupply - oldAmount)
        }
    }
    
    
    
    init() {
        self.totalSupply = 0.0
        self.playerVaults <- {} 

        // Create the Vault with the total supply of tokens and save it in storage
        //
        destroy self.account.load<@AnyResource>(from: /storage/slothMiningWarEggVault)
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: /storage/slothMiningWarEggVault)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&{FungibleToken.Receiver}>(
            /public/slothMiningWarEggReceiver,
            target: /storage/slothMiningWarEggVault
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&SlothsEggsEgg.Vault{FungibleToken.Balance}>(
            /public/slothMiningWarEggBalance,
            target: /storage/slothMiningWarEggVault
        )
        destroy self.account.load<@AnyResource>(from: /storage/slothsEggsEggAdmin)
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/slothsEggsEggAdmin)

        // Emit an event that shows that the contract was initialized
        //
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}