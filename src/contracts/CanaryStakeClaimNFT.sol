// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "../utils/Base64.sol";
import {BondType} from "../interfaces/ICanaryStakePool.sol";

/// @title CanaryStakeClaimNFT
/// @notice See the documentation in README.md at root of repository
contract CanaryStakeClaimNFT is ERC721, Owned {
    uint256 public currentTokenId;

    struct Attributes {
        address token;
        uint256 timestamp;
        uint256 claimAmount;
        BondType bondType;
    }

    mapping(uint256 tokenId => Attributes) public tokenAttributes;

    /// @dev Initializes a CanaryStakeClaimNFT contract and is owned by the admin (CanaryStakePool)
    /// @param name The name of the NFT
    /// @param symbol The symbol of the NFT
    /// @param admin The address of the admin (CanaryStakePool)
    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC721(name, symbol) Owned(admin) {}

    /// @notice Returns the URI for a given token ID
    /// @dev The NFT content static content is stored on-chain, see renderAsDataUri function
    /// @param tokenId The token ID
    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return renderAsDataUri(tokenId);
    }

    /// @notice Renders the NFT as a data URI
    /// @dev The NFT content static content is stored on-chain, see renderAsDataUri function
    /// @param _tokenId The token ID
    function renderAsDataUri(
        uint256 _tokenId
    ) public pure returns (string memory) {
        string memory svg;

        svg = string.concat(
            '<svg height="200px" width="200px" version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512" xml:space="preserve" fill="#000000">',
            '<g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <polygon style="fill:#DDB200;" points="337.172,148.439 425.339,169.791 337.172,191.15 "></polygon> <path style="fill:#FFDA44;" d="M5.312,100.032C-9.145,134.505-0.096,275.661,109.4,327.131L12.18,485.313l0,0 c37.324-2.17,70.973-23.201,89.276-55.802l0.738-1.313l4.318-0.055c51.468-0.663,101.969-14.071,146.988-39.026l0,0 c61.274-33.965,91.712-105.159,73.929-172.922l0,0c25.627-25.627,25.627-67.178,0-92.806c-0.534-0.534-1.075-1.056-1.623-1.568 c-29.299-27.385-76.372-20.63-98.07,12.812c-0.565,0.87-1.066,1.776-1.535,2.702c-4.586,9.036-31.934,61.372-50.26,61.472 C126.019,199.077,5.312,100.032,5.312,100.032z"></path> <g> <path style="fill:#DDB200;" d="M69.739,196.061c4.187-1.093,6.697-5.373,5.604-9.56c-1.093-4.187-5.372-6.698-9.56-5.604 c-35,9.13-53.975,6.432-60.124,5.001c1.144,5.459,2.499,11.009,4.077,16.606c3.227,0.376,7.104,0.637,11.697,0.637 C32.922,203.141,48.813,201.519,69.739,196.061z"></path> <path style="fill:#DDB200;" d="M89.455,246.729c4.187-1.093,6.697-5.373,5.604-9.56c-1.093-4.187-5.372-6.698-9.56-5.604 c-31.259,8.154-52.887,7.08-62.994,5.72c2.56,5.554,5.382,11.061,8.473,16.482c2.098,0.097,4.338,0.159,6.76,0.159 C50.605,253.924,68,252.326,89.455,246.729z"></path> <path style="fill:#DDB200;" d="M119.831,294.434c4.187-1.093,6.697-5.373,5.604-9.56c-1.093-4.186-5.373-6.698-9.56-5.604 c-40.769,10.637-61.021,5.23-63.734,4.411c5.315,6.205,11.428,12.224,17.756,17.791c0.462,0.005,0.445,0.01,0.92,0.01 C82.675,301.481,98.928,299.887,119.831,294.434z"></path> <circle style="fill:#DDB200;" cx="281.025" cy="169.787" r="15.477"></circle> </g> <circle style="fill:#FF3F62;" cx="466.912" cy="169.787" r="15.477"></circle> <g> <path style="fill:#A4E276;" d="M512,168.889c0,0-78.561,9.759-82.123,145.523C429.878,314.413,501.352,271.512,512,168.889z"></path> <path style="fill:#A4E276;" d="M512,168.889c0,0-78.561-9.759-82.123-145.523C429.878,23.366,501.352,66.266,512,168.889z"></path> </g> <path style="fill:#FFF5CC;" d="M279.519,272.365c0.741,69.265-45.06,130.3-111.53,149.088c30.242-6.38,59.479-17.241,86.708-32.335 l0,0c54.677-30.308,84.797-90.262,78.014-150.968L279.519,272.365L279.519,272.365z"></path> <g style="opacity:0.19;"> <path style="fill:#DDB200;" d="M327.429,219.516c25.627-25.627,25.627-67.178,0-92.806c-0.534-0.534-1.075-1.056-1.623-1.568 c-5.171-4.832-10.901-8.58-16.941-11.327c21.63,25.783,20.338,64.272-3.907,88.518l0,0 c17.783,67.763-12.654,138.958-73.929,172.922l0,0c-45.018,24.955-95.52,38.362-146.988,39.026l-4.318,0.055l-0.738,1.313 c-11.601,20.662-29.371,36.668-50.329,46.178L12.18,488.635l0,0c37.324-2.17,70.973-23.201,89.276-55.802l0.738-1.313l4.318-0.055 c51.468-0.663,101.969-14.071,146.988-39.026l0,0C314.774,358.475,345.211,287.281,327.429,219.516L327.429,219.516z"></path> </g> </g>',
            "</svg>"
        );

        string memory image = string.concat(
            '"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(svg)),
            '"'
        );

        string memory json = string.concat(
            '{"name":"Canary Claim NFT',
            LibString.toString(_tokenId),
            '","description":"You must hold this NFT in order to claim your Canary rewards from staking",',
            '"attributes": [],',
            image,
            "}"
        );

        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            );
    }

    /// @notice Burns NFT
    /// @dev Only owner can burn NFTs
    /// @param tokenId The token ID
    function burn(uint256 tokenId) external onlyOwner {
        tokenAttributes[tokenId] = Attributes(
            address(0),
            0,
            0,
            BondType.Matured
        );

        _burn(tokenId);
    }

    /// @notice Safe mints a new NFT with the given Claim attributes
    /// @param to The address to mint the NFT to
    /// @param token The address of the token
    /// @param claimAmount The claim amount
    /// @param bondType The bond type
    function safeMint(
        address to,
        address token,
        uint256 claimAmount,
        BondType bondType
    ) external onlyOwner returns (uint256) {
        uint256 newTokenId = ++currentTokenId;

        tokenAttributes[newTokenId] = Attributes(
            token,
            block.timestamp,
            claimAmount,
            bondType
        );

        _safeMint(to, newTokenId);

        return newTokenId;
    }
}
