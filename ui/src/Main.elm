module Main exposing (Model, Msg(..), init, main, subscriptions, update, view, viewLink)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url



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
    }


type alias Metadata =
    { version : String
    , registryUrl : String
    }


init : Metadata -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init meta url key =
    ( Model key url meta, Cmd.none )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


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
        , viewConnectionStatus model.meta.registryUrl
        , viewRepositories
        ]
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


viewConnectionStatus : String -> Html msg
viewConnectionStatus registryUrl =
    section [ class "status" ]
        [ div [ class "status__registry" ]
            [ img [ src "/statics/radio.svg" ] []
            , p [] [ text ("Connected to " ++ registryUrl) ]
            ]
        , div [ class "status__repositories" ]
            [ img [ src "/statics/boxes.svg" ] []
            , p [] [ text "Found 10 repositories" ]
            ]
        ]


viewRepositories : Html msg
viewRepositories =
    section [ class "repositories__title" ]
        [ h1 [] [ text "Repositories" ]
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
