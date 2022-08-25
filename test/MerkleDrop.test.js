const { ethers } = require('hardhat');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { expect } = require('chai');
// const tokens = require('./tokens.json');

async function deploy(name, ...params) {
  const Contract = await ethers.getContractFactory(name);
  return await Contract.deploy(...params).then(f => f.deployed());
}

function hashData(account,amount) {
  return Buffer.from(ethers.utils.solidityKeccak256(['address','uint256'], [account,amount]).slice(2), 'hex')
}


describe('ERC20AirDrop', function () {
  
  before(async function() {
    this.accounts = await ethers.getSigners();
    
    this.merkleTree = new MerkleTree([hashData(this.accounts[0].address,100),hashData(this.accounts[1].address,200)], keccak256, { sortPairs: true });
  });

  describe('Making user claims', function () {
    before(async function() {
      this.airDropFactory = await deploy('MerkleDropFactory');
      this.kitToken = await deploy('ERC20Token',"KIT","KIT")
      const txResponse =  await this.airDropFactory.createAirDrop("KITGIVEAWAY",this.kitToken.address,this.merkleTree.getHexRoot())

      const txReceipt = await txResponse.wait()
      const [instance] = txReceipt.events[0].args;
      this.airDropContractAddress = instance
      this.airDropContract = await ethers.getContractAt('MerkleDrop',this.airDropContractAddress)
      
      //Funding the airDropContract with some KIT tokens so that they can be used for airdrops
      await this.kitToken.mint(this.airDropContractAddress,300)
    });

    
      it('checks if the users can claim token', async function () {
        //for first user

        /**
         * Create merkle proof (anyone with knowledge of the merkle tree)
         */
        const userAddress = this.accounts[0].address
        
        const proof = this.merkleTree.getHexProof(hashData(userAddress,100));
      
        /**
         * Redeems token using merkle proof (anyone with the proof)
         */
        await expect(this.airDropContract.claim(userAddress,100,proof))
          .to.emit(this.airDropContract, 'Claim')
          .withArgs( userAddress, 100);

      });

      it('checks if user can withdraw the claimed tokens',async function(){
        //checking before balance of the user for the KIT token
        const userAddress = this.accounts[0].address
        expect(await this.kitToken.balanceOf(userAddress)).to.equal(0)

        //withdrawing the claimed tokens
        await expect(this.airDropContract.withdraw(50))
        .to.emit(this.airDropContract,'Withdraw')
        .withArgs(userAddress,50);

        //checking balance after withdraw
        expect(await this.kitToken.balanceOf(userAddress)).to.equal(50)

        expect(await this.airDropContract.remainingTokens(userAddress)).to.equal(50);
      })



      it('checks if anyone with the valid signature can withdraw tokens',async function(){
        const currentSignCountNumber = await this.airDropContract.signCountNumber();
        const messageDigest = await this.airDropContract.getMessageHash(this.accounts[2].address,20,currentSignCountNumber)
        // const signature = await this.accounts[0].signMessage(hashData(this.accounts[2].address,50,currentSignCountNumber));
        const signature = await this.accounts[0].signMessage(ethers.utils.arrayify(messageDigest))
        this.signature = signature
        //checking the user 2 balance of the KIT token before the withdraw
        expect(await this.kitToken.balanceOf(this.accounts[2].address)).to.equal(0)

        
        //making the withdraw using signature
        await expect(this.airDropContract.withdrawWithSignature(20,signature,this.accounts[2].address))
        .to.emit(this.airDropContract,'Withdraw')
        .withArgs(this.accounts[2].address,20);

         //checking the user 2 balance of the KIT token after the withdraw
         expect(await this.kitToken.balanceOf(this.accounts[2].address)).to.equal(20)

        
        
      })

      it("checks if the signature cannot be replayed",async function(){
           //reverts because the same signature is trying to be used 
         await expect(this.airDropContract.withdrawWithSignature(20,this.signature,this.accounts[2].address))
         .reverted
      })
    
  });


});