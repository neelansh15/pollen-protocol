export default {
    title: 'Pollen Protocol',
    description: 'Modules for the Lens Protocol',
    themeConfig: {
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
                        text: "ERC721 Gated",
                        link: "/follow-modules/ERC721Gated"
                    },
                    {
                        text: "ERC721 Multiple AND Gated",
                        link: "/follow-modules/ERC721MultipleANDGated"
                    },
                    {
                        text: "ERC721 Multiple OR Gated",
                        link: "/follow-modules/ERC721MultipleORGated"
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
            }
        ]
    }
}