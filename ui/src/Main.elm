module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder)
import Url exposing (Protocol(..))



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
    , url : Url.Url
    , meta : Metadata
    , catalog : RemoteData Catalog
    }


type alias Metadata =
    { version : String
    , registryUrl : String
    }


type RemoteData value
    = Failure
    | Loading
    | Success value


type alias Catalog =
    { repositories : List String
    }


init : Metadata -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init meta url key =
    ( Model key url meta Loading, getCatalog )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotCatalog (Result Http.Error Catalog)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        GotCatalog result ->
            case result of
                Ok catalog ->
                    ( { model | catalog = Success catalog }, Cmd.none )

                Err _ ->
                    ( { model | catalog = Failure }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Octopod"
    , body =
        [ viewHeader model.meta.version
        , viewConnectionStatus model.meta.registryUrl model.catalog
        , viewRepositoriesTitle
        ]
            ++ viewRepositories model.catalog
    }


viewHeader : String -> Html msg
viewHeader version =
    header [ class "header" ]
        [ div [ class "header__main" ]
            [ img [ src "/statics/logo.svg", class "header__logo" ] []
            , h1 [ class "header__title" ] [ text "Octopod" ]
            ]
        , div [ class "header__nav" ]
            [ p [] [ text ("[" ++ version ++ "]") ]
            , a [ href "https://github.com/frectonz/octopod" ] [ img [ src "/statics/github.svg" ] [] ]
            ]
        ]


viewConnectionStatus : String -> RemoteData Catalog -> Html msg
viewConnectionStatus registryUrl data =
    section [ class "status" ]
        [ div [ class "status__registry" ]
            [ img [ src "/statics/radio.svg" ] []
            , p [] [ text ("Connected to " ++ registryUrl) ]
            ]
        , div [ class "status__repositories" ]
            [ img [ src "/statics/boxes.svg" ] []
            , p []
                [ text
                    (case data of
                        Success catalog ->
                            "Found " ++ (catalog.repositories |> List.length |> String.fromInt) ++ " repositories"

                        _ ->
                            ""
                    )
                ]
            ]
        ]


viewRepositoriesTitle : Html msg
viewRepositoriesTitle =
    section [ class "repositories__title" ]
        [ h1 [] [ text "Repositories" ]
        ]


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
                            , div [] [ h1 [] [ a [ href ("/repos/" ++ repo) ] [ text repo ] ] ]
                            , div [] [ img [ src "statics/move-up-right.svg" ] [] ]
                            ]
                    )



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
