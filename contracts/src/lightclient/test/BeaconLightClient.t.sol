pragma solidity 0.8.14;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../BeaconLightClient.sol";

contract BeaconLightClientTest is DSTest, Script {
    BeaconLightClient beaconLightClient;

    function setUp() public {
        bytes32 GENESIS_VALIDATORS_ROOT = 0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb;
        uint256 GENESIS_TIME = 0;
        uint256 SECONDS_PER_SLOT = 12;
        bytes4 FORK_VERSION = 0x02001020;
        uint256 SYNC_COMMITTEE_PERIOD = 485;
        bytes32 SYNC_COMMITTEE_ROOT = 0x2572bb0751acd1f30fcef025a9fa561a9fa28bad8cd99f197ee260c6bc57a99a;
        bytes32 SYNC_COMMITTEE_POSEIDON = bytes32(uint256(5711543655693032178629450423561937340727713605265369876645612071008616051970));
        beaconLightClient = new BeaconLightClient(
            GENESIS_VALIDATORS_ROOT,
            GENESIS_TIME,
            SECONDS_PER_SLOT,
            FORK_VERSION,
            SYNC_COMMITTEE_PERIOD,
            SYNC_COMMITTEE_ROOT,
            SYNC_COMMITTEE_POSEIDON
        );
        vm.warp(9999999999999);
    }

    function testStep() public {
        BeaconBlockHeader memory attestedHeader = BeaconBlockHeader(
            3976690,
            62434,
            0xcfd440015afa43be112ea5e79452dc8232587aca62abdd242de1c42fcd8b0528,
            0x8b2e8520b646b82a093f0be87306d54c7299aeacadcd7625e1d79fb67f9c850f,
            0xeec6fb7261aacc4b6a6a0b3204fec0b211a6f8079a481dba18f552e45dfdc979
        );
        BeaconBlockHeader memory finalizedHeader = BeaconBlockHeader(
            3976608,
            71811,
            0xb13d8834b1620b7215c078e97e664bcc1f0a55c58995b40a82973d39e9d338be,
            0x268caa7b1c763f8cdaf048b18a8ba63d4e0000a712b06c5e2c632c1c72f3696f,
            0x8a622c2df9ed86bfb64eb113394b24567fc760e81d64f0aa78153b8fa1eec428
        );
        bytes32[] memory finalityBranch =  new bytes32[](6);
        finalityBranch[0] = 0x6de5010000000000000000000000000000000000000000000000000000000000;
        finalityBranch[1] = 0x04743ed6b30f3ad14dfca1198c41e3ca1610625a8c677996213efa1591b33f67;
        finalityBranch[2] = 0x6d218eaefac861f1c843a8f04c790349b85a4fe2f3a059d669a264b253c6d962;
        finalityBranch[3] = 0xfc8dc83456e6f89533d5034a3f682ce96dac39b3e8084f3660b6db01bcf17ee4;
        finalityBranch[4] = 0x1c33d7152c50e9d60747f06da338b606ffe352ad669a9414e3d79f65c4cc7b79;

        finalityBranch[5] = 0xb3af37cebbb64825f51744975ce9ae6dbb2279a50942e88acc337dadef0f708a;
        bytes32 nextSyncCommitteeRoot = 0x0;
        bytes32[] memory nextSyncCommitteeBranch = new bytes32[](0);

        bytes32 executionStateRoot = 0x2380c9d8c707ae03906cd435f06ff7763feca2bff421f7c035c87e7b4c1d336a;
        bytes32[] memory executionStateRootBranch = new bytes32[](8);
        executionStateRootBranch[0] = 0x8fc3e993516c85a37aeb20118814a4ddacab6f6c7087c68cc3096ad935e4db9e;
        executionStateRootBranch[1] = 0xe1c5f64b66ea64f97412ab5737937ff231cee76c61fd5705994622f7b44315e1;
        executionStateRootBranch[2] = 0x5cd41bbada0364af8d52d1b6d3593a9d4155330f641ae17fa1d7815c6efba2bf;
        executionStateRootBranch[3] = 0xd7f82dd1e1e1e923ba2ec807a199e443d1f737d4cba728d9b4e96bdbdfeb26f9;
        executionStateRootBranch[4] = 0x6d044c406c5b7dd01ef679e0ed60d2c09a7fb1b119e7da50e9c14161b347d08a;
        executionStateRootBranch[5] = 0xf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b;
        executionStateRootBranch[6] = 0xdb56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71;
        executionStateRootBranch[7] = 0x7397ca2d2cc9d4ae150ce594e08b5e90c57e63d0832e81c6aa8fac1cf87f2322;

        uint256[2] memory a = [
            7388516468165689389071018049450113740876766678217762637452655158826550628735,
            8953162334260694374632465162430735022481447367789278006130928025671681388657
        ];
        uint256[2][2] memory b = [
            [
                2413384933880090723104111622351561520701095659715699352422474753785503264102,
                11473167342145246871014727785716873314405219633807215705692380958808492463791
            ],
            [
                10575462521003404357077242141153156962124601991920123437664380919426880373825,
                15699433548537333861851726451946812209953804370169087354556661836247074670136
            ]
        ];
        uint256[2] memory c = [
            6706306362666034364301153095215104241713313906313754446137996221220417445649,
            16503812433494347648467655181152464990536659098412945879657094523310633194219
        ];

        uint64 participation = 411;
        Groth16Proof memory proof = Groth16Proof(a, b, c);
        BLSAggregatedSignature memory signature = BLSAggregatedSignature(participation, proof);

        LightClientUpdate memory update = LightClientUpdate(
            attestedHeader,
            finalizedHeader,
            finalityBranch,
            nextSyncCommitteeRoot,
            nextSyncCommitteeBranch,
            executionStateRoot,
            executionStateRootBranch,
            signature
        );

        beaconLightClient.step(update);
    }

    function testUpdateNextSyncCommittee() public {
        BeaconBlockHeader memory attestedHeader = BeaconBlockHeader(
            3976636,
            109415,
            0x0e3ff2db264240bd75f821848bd0a077544c5a4b5c3c231dbd98a52a82d857c8,
            0x76366916e3f9538a53d22f21f2edc9457ec45f3af4974a405614c01d943d1dd9,
            0xd76ab975b30c516c656069da5fc14352b44501d5e161ca265f9f35e111200d3a
        );
        BeaconBlockHeader memory finalizedHeader = BeaconBlockHeader(
            3976544,
            198137,
            0xa753318963779bfe8bf25228087ba8e2d4a200ce2c3741e4204d0104806e1a8e,
            0x7e1521100cfd3d3593c1665a82e2c3e9950e629e15d765c23346f85ec34bc381,
            0x2ccfdd16e69cf5ac9bb8cbd85bbe0c91fcf666c448bbde3aacf14f54e36d7933
        );
        bytes32[] memory finalityBranch =  new bytes32[](6);
        finalityBranch[0] = 0x6be5010000000000000000000000000000000000000000000000000000000000;
        finalityBranch[1] = 0x04743ed6b30f3ad14dfca1198c41e3ca1610625a8c677996213efa1591b33f67;
        finalityBranch[2] = 0x6d218eaefac861f1c843a8f04c790349b85a4fe2f3a059d669a264b253c6d962;
        finalityBranch[3] = 0x86f367f14f4679915f9400220e65ea3eabf1d93c5f61168a7a639fcd24fb48aa;
        finalityBranch[4] = 0x000811e772c5ed0b5509c90d008655f8559b002fc7cfd596f7dc37de90bbc007;
        finalityBranch[5] = 0x2d3559435fea4ba68f948eb27a79b6035127c18114085c145467cf50d0584e55;

        bytes32 nextSyncCommitteeRoot = 0xc1bcfd9c44c8b9fec443530f7cf06f281c6b5d2d1ede77a486eea591fe79b0b5;
        bytes32[] memory nextSyncCommitteeBranch = new bytes32[](5);
        nextSyncCommitteeBranch[0] = 0x2572bb0751acd1f30fcef025a9fa561a9fa28bad8cd99f197ee260c6bc57a99a;
        nextSyncCommitteeBranch[1] = 0x67cf535bdc97f271ee183d82698fe8b7b6f84e8746a35a6a65e0311bfe0aa8a8;
        nextSyncCommitteeBranch[2] = 0xc9eb07afb0ae71ca7a0747dd6da6c22f84290e16a86eb2efc6753125171f167d;
        nextSyncCommitteeBranch[3] = 0x3c4b67a809617b0f2f9d3640db723dc36a967f8a11ae99ed86241f4b79a84879;
        nextSyncCommitteeBranch[4] = 0xf9c348f25fb4d9ffac9f84a31aa95d94556cba966db2afbe8b7ba478c554778c;

        uint256[2] memory a = [
            3200921791163197869039941374630363522532978129195596155391620520345538643379,
            6086553045478370602817721782721791728890340125024700001353456352651844560387
        ];
        uint256[2][2] memory b = [
            [
                18006188230839626863685122298649417407647984308207751796760810229018793285767,
                14049922318996921724182538444020017109380683778101144227339183053329512913454
            ],
            [
                4474807155224097028892496364697555220381231913686011779172059989677412110524,
                8231189882205444606831902190972546693470245129661669634086020918696667863901
            ]
        ];
        uint256[2] memory c = [
            18165608402151720563892249234698509923263824946573687937988936457509068922562,
            15381712767627580108468337835083929618131736409894254885720883655916047708930
        ];

        uint64 participation = 418;
        Groth16Proof memory proof = Groth16Proof(a, b, c);
        BLSAggregatedSignature memory signature = BLSAggregatedSignature(participation, proof);

        bytes32 executionStateRoot = 0x0;
        bytes32[] memory executionStateRootBranch = new bytes32[](0);

        LightClientUpdate memory update = LightClientUpdate(
            attestedHeader,
            finalizedHeader,
            finalityBranch,
            nextSyncCommitteeRoot,
            nextSyncCommitteeBranch,
            executionStateRoot,
            executionStateRootBranch,
            signature
        );

        uint256[2] memory _a = [
            12152397041964315130539108617273282399808642066211721395743486913835800693827,
            9024169261987915898301528103864734285594567546137027384307445524748829452833
        ];
        uint256[2][2] memory _b = [
            [
                2161528839675875631882623004929831732273182610522205384859366966591761420487,
                13022069722987684693772787589134181202390103921609468223218533922352291117350
            ],
            [
                7047844274898237467013272624013634262446433914150012982070338179279198855690,
                12274730775870782337700497337851226109040641262388290382048881738288991306777
            ]
        ];
        uint256[2] memory _c = [
            10875205719565614313477171379998186914503403865320442768185530591274459014034,
            21337795083864096593025666271209832911345684940817194395632907850251006493322
        ];
        Groth16Proof memory _proof = Groth16Proof(_a, _b, _c);
        bytes32 nextSyncCommitteePoseidon = bytes32(uint256(10335401746955809104434513468092609543236012266259715749534868954063185842109));

        console.logBytes32(bytes32(uint256(5711543655693032178629450423561937340727713605265369876645612071008616051970)));

        beaconLightClient.updateSyncCommittee(update, nextSyncCommitteePoseidon, _proof);
    }
}
