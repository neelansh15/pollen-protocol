export default {
    title: 'Pollen Protocol',
    description: 'Modules for the Lens Protocol',
    head: [
        ['link', { rel: "apple-touch-icon", sizes: "180x180", href: "https://files.readme.io/3f3641a-small-herb_1f33f.png" }],
        ['link', { rel: "icon", type: "image/png", sizes: "32x32", href: "https://files.readme.io/3f3641a-small-herb_1f33f.png" }],
        ['link', { rel: "icon", type: "image/png", sizes: "16x16", href: "https://files.readme.io/3f3641a-small-herb_1f33f.png" }],
    ],
    themeConfig: {
        logo: 'https://files.readme.io/3f3641a-small-herb_1f33f.png',
        editLink: {
            pattern: 'https://github.com/neelansh15/pollen-protocol/edit/main/docs/:path'
        },
        sidebar: [
            {
                text: 'Introduction',
                items: [
                    {
                        text: "Getting Started",
                        link: '/getting-started'
                    },
                    {
                        text: "Lens Modules",
                        link: '/lens-modules'
                    },
                    {
                        text: "Protocol",
                        link: '/protocol'
                    },
                    {
                        text: "Deployments",
                        link: '/deployments'
                    },
                ]
            },
            {
                text: 'Follow Modules',
                items: [
                    {
                        text: "Introduction",
                        link: "/follow-modules/"
                    },
                    {
                        text: "NFT Gated",
                        link: "/follow-modules/NFTGated"
                    },
                    {
                        text: "NFT Multiple AND Gated",
                        link: "/follow-modules/NFTMultipleANDGated"
                    },
                    {
                        text: "NFT Multiple OR Gated",
                        link: "/follow-modules/NFTMultipleORGated"
                    },
                    {
                        text: "Profile Multiple AND Gated",
                        link: "/follow-modules/ProfileMultipleANDGated"
                    },
                    {
                        text: "Profile Multiple OR Gated",
                        link: "/follow-modules/ProfileMultipleORGated"
                    },
                ]
            },
            {
                text: 'Reference Modules',
                items: [
                    {
                        text: "Introduction",
                        link: "/reference-modules/"
                    },
                    {
                        text: "Limited Rewards",
                        link: "/reference-modules/LimitedRewards"
                    },
                    {
                        text: "Limited Rewards Exponential",
                        link: "/reference-modules/LimitedRewardsExponential"
                    },
                ]
            }
        ]
    }
}