module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import DateFormat
import Filesize
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Time exposing (Posix)
import Url exposing (Protocol(..), Url)
import Url.Parser as Parser exposing ((<?>), Parser)
import Url.Parser.Query as Query



-- MAIN


main : Program Metadata Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , meta : Metadata
    , page : Page
    }


type alias Metadata =
    { version : String
    , registryUrl : String
    }


type Route
    = Index
    | Repo (Maybe String)
    | Tag (Maybe String) (Maybe String)


type Page
    = HomePage (RemoteData Catalog)
    | SingleRepoPage String (RemoteData Repository)
    | ImagePage String String (RemoteData Image) (RemoteData ImageBlob)


type RemoteData value
    = Failure
    | Loading
    | Success value


type alias Catalog =
    { repositories : List String
    }


type alias Repository =
    { name : String
    , tags : List String
    }


type alias Image =
    { config : ImageDigest
    , layers : List ImageDigest
    , mediaType : String
    , schemaVersion : Int
    }


type alias ImageDigest =
    { digest : String
    , mediaType : String
    , size : Int
    }


type alias ImageBlob =
    { architecture : String
    , os : String
    , cmd : List String
    , createdAt : String
    }


init : Metadata -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init meta url key =
    let
        route =
            parseUrl url
    in
    ( { key = key
      , meta = meta
      , page =
            case route of
                Index ->
                    HomePage Loading

                Repo (Just name) ->
                    SingleRepoPage name Loading

                Tag (Just repo) (Just tag) ->
                    ImagePage repo tag Loading Loading

                _ ->
                    HomePage Loading
      }
    , case route of
        Index ->
            getCatalog

        Repo (Just name) ->
            getRepo name

        Tag (Just repo) (Just tag) ->
            getImage repo tag

        _ ->
            getCatalog
    )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotCatalog (Result Http.Error Catalog)
    | GotRepository (Result Http.Error Repository)
    | GotImage (Result Http.Error Image)
    | GotImageBlob (Result Http.Error ImageBlob)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    let
                        ( newModel, newCmd ) =
                            init model.meta url model.key
                    in
                    ( newModel, Cmd.batch [ Nav.pushUrl model.key (Url.toString url), newCmd ] )

                Browser.External href ->
                    ( model, Nav.load href )

        ( UrlChanged url, page ) ->
            let
                route =
                    parseUrl url

                pageChanged =
                    case ( route, page ) of
                        ( Index, HomePage _ ) ->
                            False

                        ( Repo _, SingleRepoPage _ _ ) ->
                            False

                        ( Tag _ _, ImagePage _ _ _ _ ) ->
                            False

                        _ ->
                            True
            in
            if pageChanged then
                init model.meta url model.key

            else
                ( model, Cmd.none )

        ( GotCatalog result, HomePage _ ) ->
            case result of
                Ok catalog ->
                    ( { model | page = HomePage (Success catalog) }, Cmd.none )

                Err _ ->
                    ( { model | page = HomePage Failure }, Cmd.none )

        ( GotRepository result, SingleRepoPage name _ ) ->
            case result of
                Ok repo ->
                    ( { model | page = SingleRepoPage name (Success repo) }, Cmd.none )

                Err _ ->
                    ( { model | page = SingleRepoPage name Failure }, Cmd.none )

        ( GotImage result, ImagePage repo tag _ blob ) ->
            case result of
                Ok image ->
                    ( { model | page = ImagePage repo tag (Success image) blob }, getImageBlob repo image.config.digest )

                Err _ ->
                    ( { model | page = ImagePage repo tag Failure blob }, Cmd.none )

        ( GotImageBlob result, ImagePage repo tag imageData _ ) ->
            case result of
                Ok blob ->
                    ( { model | page = ImagePage repo tag imageData (Success blob) }, Cmd.none )

                Err _ ->
                    ( { model | page = ImagePage repo tag imageData Failure }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        pluralize singular plural num =
            if num == 1 then
                singular

            else
                plural

        stat =
            case model.page of
                HomePage (Success catalog) ->
                    "Found " ++ (catalog.repositories |> List.length |> String.fromInt) ++ pluralize " repository" " repositories" (catalog.repositories |> List.length)

                SingleRepoPage _ (Success repo) ->
                    "Found " ++ (repo.tags |> List.length |> String.fromInt) ++ pluralize " tag" " tags" (repo.tags |> List.length)

                ImagePage _ _ (Success image) _ ->
                    "Found " ++ (image.layers |> List.length |> String.fromInt) ++ pluralize " layer" " layers" (image.layers |> List.length)

                _ ->
                    ""
    in
    { title = "Octopod"
    , body =
        [ viewHeader model.meta.version
        , viewStat model.meta.registryUrl stat
        ]
            ++ (case model.page of
                    HomePage data ->
                        viewHomePage data

                    SingleRepoPage name data ->
                        viewSingleRepoPage name data

                    ImagePage repo tag data blob ->
                        viewImagePage model.meta.registryUrl (repo ++ ":" ++ tag) data blob
               )
    }


viewHeader : String -> Html msg
viewHeader version =
    header [ class "header" ]
        [ div [ class "header__main" ]
            [ img [ src "/statics/logo.svg", class "header__logo" ] []
            , h1 [ class "header__title" ] [ a [ href "/" ] [ text "Octopod" ] ]
            ]
        , div [ class "header__nav" ]
            [ p [] [ text ("[" ++ version ++ "]") ]
            , a [ href "https://github.com/frectonz/octopod" ] [ img [ src "/statics/github.svg" ] [] ]
            ]
        ]


viewStat : String -> String -> Html msg
viewStat registryUrl stat =
    section [ class "status" ]
        [ div [ class "status__registry" ]
            [ img [ src "/statics/radio.svg" ] []
            , p [] [ text ("Connected to " ++ registryUrl) ]
            ]
        , div [ class "status__repositories" ]
            [ img [ src "/statics/boxes.svg" ] []
            , p [] [ text stat ]
            ]
        ]


viewPageTitle : String -> Html msg
viewPageTitle title =
    section [ class "page__title" ]
        [ h1 [] [ text title ]
        ]


viewHomePage : RemoteData Catalog -> List (Html msg)
viewHomePage data =
    viewPageTitle "Repositories"
        :: viewRepositories data


viewRepositories : RemoteData Catalog -> List (Html msg)
viewRepositories data =
    case data of
        Loading ->
            [ section [ class "loading__title" ] [ h1 [] [ text "Loading..." ] ] ]

        Failure ->
            [ section [ class "failure__title" ] [ h1 [] [ text "Something went wrong" ] ] ]

        Success catalog ->
            catalog.repositories
                |> List.map
                    (\repo ->
                        section [ class "repo" ]
                            [ div [] [ img [ src "/statics/box.svg" ] [] ]
                            , div [] [ h1 [] [ a [ href ("/repos?r=" ++ repo) ] [ text repo ] ] ]
                            , div [] [ img [ src "/statics/move-up-right.svg" ] [] ]
                            ]
                    )


viewSingleRepoPage : String -> RemoteData Repository -> List (Html msg)
viewSingleRepoPage name data =
    viewPageTitle name
        :: viewRepoDetails data


viewRepoDetails : RemoteData Repository -> List (Html msg)
viewRepoDetails data =
    case data of
        Loading ->
            [ section [ class "loading__title" ] [ h1 [] [ text "Loading..." ] ] ]

        Failure ->
            [ section [ class "failure__title" ] [ h1 [] [ text "Something went wrong" ] ] ]

        Success repo ->
            repo.tags
                |> List.map
                    (\tag ->
                        section [ class "repo" ]
                            [ div [] [ img [ src "/statics/tag.svg" ] [] ]
                            , div [] [ h1 [] [ a [ href ("/tags?r=" ++ repo.name ++ "&t=" ++ tag) ] [ text tag ] ] ]
                            , div [] [ img [ src "/statics/move-up-right.svg" ] [] ]
                            ]
                    )


viewImagePage : String -> String -> RemoteData Image -> RemoteData ImageBlob -> List (Html msg)
viewImagePage registryUrl name data blob =
    viewPageTitle name
        :: viewImageDetail registryUrl name data blob


viewImageDetail : String -> String -> RemoteData Image -> RemoteData ImageBlob -> List (Html msg)
viewImageDetail registryUrl name data blob =
    case data of
        Loading ->
            [ section [ class "loading__title" ] [ h1 [] [ text "Loading..." ] ] ]

        Failure ->
            [ section [ class "failure__title" ] [ h1 [] [ text "Something went wrong" ] ] ]

        Success image ->
            let
                size =
                    (image.layers |> List.map (\l -> l.size) |> List.sum) + image.config.size
            in
            [ section [ class "image" ]
                [ div [ class "layers" ]
                    (h2 [ class "layers__title" ] [ text "Layers" ]
                        :: (image.layers
                                |> List.map
                                    (\layer ->
                                        div []
                                            [ p [] [ text layer.digest ]
                                            , p [] [ layer.size |> Filesize.format |> text ]
                                            ]
                                    )
                           )
                    )
                , div [ class "metadata" ]
                    ([ div []
                        [ h2 [] [ text "Pull Command" ]
                        , p [] [ text ("docker pull " ++ registryUrl ++ "/" ++ name) ]
                        ]
                     , div []
                        [ h2 [] [ text "Image Digest" ]
                        , p [] [ text image.config.digest ]
                        ]
                     , div []
                        [ h2 [] [ text "Image Size" ]
                        , p [] [ size |> Filesize.format |> text ]
                        ]
                     ]
                        ++ (case blob of
                                Loading ->
                                    []

                                Failure ->
                                    []

                                Success blobData ->
                                    [ div []
                                        [ h2 [] [ text "Architecture" ]
                                        , p [] [ text blobData.architecture ]
                                        ]
                                    , div []
                                        [ h2 [] [ text "Created At" ]
                                        , p [] [ text blobData.createdAt ]
                                        ]
                                    , div []
                                        [ h2 [] [ text "OS" ]
                                        , p [] [ text blobData.os ]
                                        ]
                                    , div []
                                        [ h2 [] [ text "CMD" ]
                                        , p [] [ blobData.cmd |> String.join " " |> text ]
                                        ]
                                    ]
                           )
                    )
                ]
            ]



-- HTTP


getCatalog : Cmd Msg
getCatalog =
    Http.get
        { url = "/api/v2/_catalog"
        , expect = Http.expectJson GotCatalog decodeCatalog
        }


decodeCatalog : Decoder Catalog
decodeCatalog =
    Decode.map Catalog
        (Decode.field "repositories" (Decode.list Decode.string))


getRepo : String -> Cmd Msg
getRepo repo =
    Http.get
        { url = "/api/v2/" ++ repo ++ "/tags/list"
        , expect = Http.expectJson GotRepository decodeRepo
        }


decodeRepo : Decoder Repository
decodeRepo =
    Decode.map2 Repository
        (Decode.field "name" Decode.string)
        (Decode.field "tags" (Decode.list Decode.string))


getImage : String -> String -> Cmd Msg
getImage repo tag =
    Http.get
        { url = "/api/v2/" ++ repo ++ "/manifests/" ++ tag
        , expect = Http.expectJson GotImage decodeImage
        }


decodeImage : Decoder Image
decodeImage =
    Decode.map4 Image
        (Decode.field "config" decodeImageDigest)
        (Decode.field "layers" (Decode.list decodeImageDigest))
        (Decode.field "mediaType" Decode.string)
        (Decode.field "schemaVersion" Decode.int)


decodeImageDigest : Decoder ImageDigest
decodeImageDigest =
    Decode.map3 ImageDigest
        (Decode.field "digest" Decode.string)
        (Decode.field "mediaType" Decode.string)
        (Decode.field "size" Decode.int)


getImageBlob : String -> String -> Cmd Msg
getImageBlob repo blobDigest =
    Http.get
        { url = "/api/v2/" ++ repo ++ "/blobs/" ++ blobDigest
        , expect = Http.expectJson GotImageBlob decodeImageBlob
        }


decodeImageBlob : Decoder ImageBlob
decodeImageBlob =
    Decode.map4 ImageBlob
        (Decode.field "architecture" Decode.string)
        (Decode.field "os" Decode.string)
        (Decode.field "config" (Decode.field "Cmd" (Decode.list Decode.string)))
        (Decode.field "created" (Iso8601.decoder |> Decode.map dateFormatter))



-- ROUTES


parseUrl : Url -> Route
parseUrl url =
    case Parser.parse routeParser url of
        Just route ->
            route

        Nothing ->
            Index


routeParser : Parser (Route -> c) c
routeParser =
    Parser.oneOf
        [ Parser.map Index Parser.top
        , Parser.map Repo (Parser.s "repos" <?> Query.string "r")
        , Parser.map Tag (Parser.s "tags" <?> Query.string "r" <?> Query.string "t")
        ]



-- DATE FORMATTER


dateFormatter : Posix -> String
dateFormatter =
    DateFormat.format
        [ DateFormat.monthNameFull
        , DateFormat.text " "
        , DateFormat.dayOfMonthSuffix
        , DateFormat.text ", "
        , DateFormat.yearNumber
        , DateFormat.text " "
        , DateFormat.hourFixed
        , DateFormat.text ":"
        , DateFormat.minuteFixed
        , DateFormat.text ":"
        , DateFormat.secondFixed
        ]
        Time.utc
