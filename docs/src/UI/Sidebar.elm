module UI.Sidebar exposing (viewSidebar, viewTableOfContents)

import Domain.Index exposing (Index)
import Html exposing (Html)
import Html.Attributes as Attr
import Markdown.Block
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer
import UI
import Url exposing (Url)
import Utils.String


sidebarSections : List Section
sidebarSections =
    [ Section "Guide"
        "/guide"
        [ Link "Overview" "/guide"
        , Link "The CLI" "/guide/cli"
        , Link "Routing" "/guide/routing"
        , Link "Pages" "/guide/pages"
        , Link "Shared State" "/guide/shared-state"
        , Link "Requests" "/guide/requests"
        , Link "Views" "/guide/views"
        ]
    , Section "Examples"
        "/guide"
        [ Link "User Authentication" "/guide/users"
        , Link "Elm UI" "/guide/apis"
        , Link "Page Transitions" "/guide/transitions"
        ]
    ]


parseTableOfContents : String -> List Section
parseTableOfContents =
    Markdown.Parser.parse
        >> Result.mapError (\_ -> "Failed to parse.")
        >> Result.andThen (Markdown.Renderer.render tableOfContentsRenderer)
        >> Result.withDefault []
        >> List.filterMap identity
        >> headersToSections


type alias Section =
    { header : String
    , url : String
    , links : List Link
    }


type alias Link =
    { name : String
    , url : String
    }


type alias Header =
    ( HeaderLevel, String, Maybe String )


type HeaderLevel
    = Heading2
    | Heading3


headersToSections : List Header -> List Section
headersToSections =
    let
        loop : Header -> ( List Section, Maybe Section ) -> ( List Section, Maybe Section )
        loop ( level, text, url_ ) ( sections, current ) =
            let
                url =
                    url_ |> Maybe.map (Utils.String.toId >> (++) "#") |> Maybe.withDefault ""
            in
            case ( level, current ) of
                ( Heading2, Just existing ) ->
                    ( sections ++ [ existing ], Just { header = text, url = url, links = [] } )

                ( Heading2, Nothing ) ->
                    ( sections, Just { header = text, url = url, links = [] } )

                ( Heading3, Just existing ) ->
                    ( sections, Just { existing | links = existing.links ++ [ { name = text, url = url } ] } )

                ( Heading3, Nothing ) ->
                    ( sections ++ [ { header = text, url = url, links = [] } ], Nothing )
    in
    List.foldl loop ( [], Nothing )
        >> (\( sections, maybe ) ->
                maybe
                    |> Maybe.map (\section -> sections ++ [ section ])
                    |> Maybe.withDefault sections
           )


tableOfContentsRenderer : Markdown.Renderer.Renderer (Maybe Header)
tableOfContentsRenderer =
    { heading =
        \{ level, rawText } ->
            case level of
                Markdown.Block.H1 ->
                    Just ( Heading2, rawText, Nothing )

                Markdown.Block.H2 ->
                    Just ( Heading2, rawText, Just rawText )

                Markdown.Block.H3 ->
                    Just ( Heading3, rawText, Just rawText )

                _ ->
                    Nothing
    , paragraph = \_ -> Nothing
    , blockQuote = \_ -> Nothing
    , html = Markdown.Html.oneOf []
    , text = \_ -> Nothing
    , codeSpan = \_ -> Nothing
    , strong = \_ -> Nothing
    , emphasis = \_ -> Nothing
    , hardLineBreak = Nothing
    , link = \_ _ -> Nothing
    , image = \_ -> Nothing
    , unorderedList = \_ -> Nothing
    , orderedList = \_ _ -> Nothing
    , codeBlock = \_ -> Nothing
    , thematicBreak = Nothing
    , table = \_ -> Nothing
    , tableHeader = \_ -> Nothing
    , tableBody = \_ -> Nothing
    , tableRow = \_ -> Nothing
    , tableCell = \_ _ -> Nothing
    , tableHeaderCell = \_ _ -> Nothing
    }


viewSidebar : { url : Url, index : Index } -> Html msg
viewSidebar { url } =
    let
        viewSidebarLink : Link -> Html msg
        viewSidebarLink link__ =
            viewDocumentationLink (url.path == link__.url) link__

        viewSidebarSection : Section -> Html msg
        viewSidebarSection section =
            UI.col.sm []
                [ Html.h4 [ Attr.class "h4 bold" ] [ Html.text section.header ]
                , if List.isEmpty section.links then
                    Html.text ""

                  else
                    UI.col.md [ Attr.class "border-left pad-y-sm pad-x-md align-left" ] (List.map viewSidebarLink section.links)
                ]
    in
    UI.col.md [] (List.map viewSidebarSection sidebarSections)


viewDocumentationLink : Bool -> Link -> Html msg
viewDocumentationLink isActive link__ =
    Html.a
        [ Attr.class "link"
        , Attr.classList [ ( "bold text-blue", isActive ) ]
        , Attr.href link__.url
        ]
        [ Html.text link__.name ]


viewTableOfContents : { url : Url, content : String } -> Html msg
viewTableOfContents { url, content } =
    let
        viewTableOfContentsLink : Link -> Html msg
        viewTableOfContentsLink link__ =
            viewDocumentationLink (url.fragment == Nothing && link__.url == "" || (url.fragment |> Maybe.map ((++) "#")) == Just link__.url) link__

        viewTocSection : Section -> Html msg
        viewTocSection section =
            Html.div [ Attr.class "col gap-xs align-left" ]
                [ viewTableOfContentsLink { name = section.header, url = section.url }
                , if List.isEmpty section.links then
                    Html.text ""

                  else
                    Html.div [ Attr.class "col pad-left-sm pad-xs gap-sm" ]
                        (section.links
                            |> List.map (\l -> Html.div [ Attr.class "h6" ] [ viewTableOfContentsLink l ])
                        )
                ]
    in
    if String.isEmpty content then
        Html.text ""

    else
        Html.nav [ Attr.class "col gap-md align-left toc shadow rounded bg-white" ]
            [ Html.h4 [ Attr.class "h4 bold" ] [ Html.text "On this page" ]
            , Html.div [ Attr.class "col gap-md" ] (List.map viewTocSection (parseTableOfContents content))
            ]
