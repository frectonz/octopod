module Main exposing (Model, Msg(..), init, main, subscriptions, update, view, viewLink)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url



-- MAIN


main : Program () Model Msg
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
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model key url, Cmd.none )



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
        [ viewHeader
        , viewConnectionStatus
        , viewRepositories
        ]
    }


viewHeader : Html msg
viewHeader =
    header [ class "header" ]
        [ div [ class "header__main" ]
            [ img [ src "/statics/logo.svg", class "header__logo" ] []
            , h1 [ class "header__title" ] [ text "Octopod" ]
            ]
        , div [ class "header__nav" ]
            [ p [] [ text "[0.1.0]" ]
            , a [ href "https://github.com/frectonz/octopod" ] [ img [ src "/statics/github.svg" ] [] ]
            ]
        ]


viewConnectionStatus : Html msg
viewConnectionStatus =
    section [ class "status" ]
        [ div [ class "status__registry" ]
            [ img [ src "/statics/radio.svg" ] []
            , p [] [ text "Connected to http://164.160.187.161:4003" ]
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
