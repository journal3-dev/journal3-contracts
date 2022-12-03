// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


struct Checkpoints {
    uint checkpoint_addr;
    string checkpoint_name;
    address[] candidates;
}

struct Job {
    string metadata_ipfs;
    mapping(uint=>uint[]) qualifications;
    mapping(uint=>Checkpoints) candidate_profiles;
    uint256 jou_staked;
    bool is_active;
    address closing_indexer;
    bool gasless_experience;
    uint root;
}

contract Journal3Jobs is Ownable{

    uint job_cnt;
    mapping (uint => Job) public all_jobs;
    mapping (address=>uint) skill_creator_rewards;
    
    event staking_successful(uint idx, uint amount);
    IERC20 jou;
    IERC1155 skills_repo;

    constructor(address jou_address, address skill_std){
        job_cnt = 0;
        jou = IERC20(jou_address);
        skills_repo = IERC1155(skill_std);
    }

    function createJob(string memory metadata_ipfs, uint[] memory qualifications, uint[][] memory qualification_filtering, Checkpoints[] memory checkpoints, uint checkpoint_size, uint qualifications_size, uint root, address closing_indexer) public returns(bool){
        Job storage tempJob = all_jobs[job_cnt];
        tempJob.metadata_ipfs = metadata_ipfs;
        
        tempJob.root = root;

        for (uint i=0; i < checkpoint_size; i++){
            tempJob.candidate_profiles[checkpoints[i].checkpoint_addr] = checkpoints[i];
        }

        for (uint i=0; i < qualifications_size; i++){
            for(uint j=0; j < qualifications_size; j++){
                if(qualification_filtering[i][j]==1){
                    tempJob.qualifications[qualifications[i]].push(qualifications[j]);
                }
            }
        }
        tempJob.is_active = false;
        tempJob.jou_staked = 0;
        tempJob.closing_indexer = closing_indexer;
        job_cnt++;

        return true;


    }

    function stake_jou_job(uint idx, uint amount) public {
        require(amount > 0, "InvalidAmountException");
        uint256 allowance = jou.allowance(msg.sender, address(this));
        require(allowance >= amount, "AllowanceException");
        jou.transferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(amount);
        all_jobs[idx].jou_staked += amount;
        all_jobs[idx].is_active = true;
        emit staking_successful(idx, amount);

    }
    
    function apply_job(uint idx) public {
        require(all_jobs[idx].is_active==true, "Job is not open yet");
        require(all_jobs[idx].jou_staked!=0, "Job not accepting more applicants");

        uint currnode = all_jobs[idx].root;
        
        while (currnode!=0){
            if (skills_repo.balanceOf(msg.sender, currnode)==1){
                currnode = all_jobs[idx].qualifications[currnode][0];
                if(all_jobs[idx].candidate_profiles[currnode].checkpoint_addr==currnode){
                    all_jobs[idx].candidate_profiles[currnode].candidates.push(msg.sender);
                }
                // skill_creation_fees = all_jobs[idx].jou_staked/400000;
                // skill_creator_rewards[skills_repo.get_creator_token_id_map(currnode)] += ;
            }
            else{
                currnode = all_jobs[idx].qualifications[currnode][1];
            }
        }
    } 

    function close_job(uint idx) public returns(bool) {
        require(msg.sender==owner()	|| msg.sender==all_jobs[idx].closing_indexer, "Unauthorized Closer");
        if(all_jobs[idx].is_active == true){
            all_jobs[idx].is_active = false;
            return true;
        }
        return false;
    }

    function claim_royalties_skill_creator() public {
        jou.transfer(msg.sender, skill_creator_rewards[msg.sender]);
        skill_creator_rewards[msg.sender] = 0;
    }

    // function claim_reward_validator() public {

    // }

     
}