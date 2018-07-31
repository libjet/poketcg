; continuation of Bank0 Start
; meant as the main loop, but the game never returns from _GameLoop anyway
GameLoop: ; 4000 (1:4000)
	di
	ld sp, $e000
	call ResetSerial
	call EnableInt_VBlank
	call EnableInt_Timer
	call EnableSRAM
	ld a, [s0a006]
	ld [wTextSpeed], a
	ld a, [s0a009]
	ld [wSkipDelayAllowed], a
	call DisableSRAM
	ld a, 1
	ld [wUppercaseHalfWidthLetters], a
	ei
	farcall CommentedOut_1a6cc
	ldh a, [hKeysHeld]
	cp A_BUTTON | B_BUTTON
	jr z, .ask_erase_backup_ram
	farcall _GameLoop
	jr GameLoop
.ask_erase_backup_ram
	call SetupResetBackUpRamScreen
	call EmptyScreen
	ldtx hl, ResetBackUpRamText
	call YesOrNoMenuWithText
	jr c, .reset_game
; erase sram
	call EnableSRAM
	xor a
	ld [s0a000], a
	call DisableSRAM
.reset_game
	jp Reset

Func_4050: ; 4050 (1:4050)
	farcall Func_1996e
	ld a, 1
	ld [wUppercaseHalfWidthLetters], a
	ret

; basic setup to be able to print the ResetBackUpRamText in an empty screen
SetupResetBackUpRamScreen: ; 405a (1:405a)
	xor a ; SYM_SPACE
	ld [wTileMapFill], a
	call DisableLCD
	call LoadSymbolsFont
	call SetDefaultPalettes
	lb de, $38, $7f
	call SetupText
	ret
; 0x406e

CommentedOut_406e: ; 406e (1:406e)
	ret
; 0x406f

; try to resume a saved duel from the main menu
TryContinueDuel: ; 406f (1:406f)
	call SetupDuel
	call Func_66e9
	ldtx hl, BackUpIsBrokenText
	jr c, HandleFailedToContinueDuel
;	fallthrough

_ContinueDuel: ; 407a (1:407a)
	ld hl, sp+$00
	ld a, l
	ld [wDuelReturnAddress], a
	ld a, h
	ld [wDuelReturnAddress + 1], a
	call ClearJoypad
	ld a, [wDuelTheme]
	call PlaySong
	xor a
	ld [wDuelFinished], a
	call DuelMainInterface
	jp MainDuelLoop.between_turns
; 0x4097

HandleFailedToContinueDuel: ; 4097 (1:4097)
	call DrawWideTextBox_WaitForInput
	call ResetSerial
	scf
	ret
; 0x409f

; this function begins the duel after the opponent's graphics, name and deck have been introduced
; loads both player's decks and sets up the variables and resources required to begin a duel.
StartDuel: ; 409f (1:409f)
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	ld a, DUELIST_TYPE_PLAYER
	ld [wPlayerDuelistType], a
	ld a, [wcc19]
	ld [wOpponentDeckID], a
	call LoadPlayerDeck
	call SwapTurn
	call LoadOpponentDeck
	call SwapTurn
	jr .decks_loaded

; unreferenced?
	ld a, MUSIC_DUEL_THEME_1
	ld [wDuelTheme], a
	ld hl, wOpponentName
	xor a
	ld [hli], a
	ld [hl], a
	ld [wIsPracticeDuel], a

.decks_loaded
	ld hl, sp+$0
	ld a, l
	ld [wDuelReturnAddress], a
	ld a, h
	ld [wDuelReturnAddress + 1], a
	xor a
	ld [wCurrentDuelMenuItem], a
	call SetupDuel
	ld a, [wcc18]
	ld [wDuelInitialPrizes], a
	call InitVariablesToBeginDuel
	ld a, [wDuelTheme]
	call PlaySong
	call Func_4b60
	ret c
;	fallthrough

; the loop returns here after every turn switch
MainDuelLoop ; 40ee (1:40ee)
	xor a
	ld [wCurrentDuelMenuItem], a
	call UpdateSubstatusConditions_StartOfTurn
	call DisplayDuelistTurnScreen
	call HandleTurn

.between_turns
	call ExchangeRNG
	ld a, [wDuelFinished]
	or a
	jr nz, .duel_finished
	call UpdateSubstatusConditions_EndOfTurn
	call HandleBetweenTurnsEvents
	call Func_3b31
	call ExchangeRNG
	ld a, [wDuelFinished]
	or a
	jr nz, .duel_finished
	ld hl, wDuelTurns
	inc [hl]
	ld a, [wDuelType]
	cp DUELTYPE_PRACTICE
	jr z, .practice_duel

.next_turn
	call SwapTurn
	jr MainDuelLoop

.practice_duel
	ld a, [wIsPracticeDuel]
	or a
	jr z, .next_turn
	ld a, [hl]
	cp 15 ; the practice duel lasts 15 turns
	jr c, .next_turn
	xor a ; DUEL_WIN
	ld [wDuelResult], a
	ret

.duel_finished
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	ld a, BOXMSG_DECISION
	call DrawDuelBoxMessage
	ldtx hl, DecisionText
	call DrawWideTextBox_WaitForInput
	call EmptyScreen
	ldh a, [hWhoseTurn]
	push af
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	call DrawDuelistPortraitsAndNames
	call PrintDuelResultStats
	pop af
	ldh [hWhoseTurn], a
	call Func_3b21
	ld a, [wDuelFinished]
	cp TURN_PLAYER_WON
	jr z, .active_duelist_won_battle
	cp TURN_PLAYER_LOST
	jr z, .active_duelist_lost_batte
	ld a, $5f
	ld c, MUSIC_DARK_DIDDLY
	ldtx hl, DuelWasADrawText
	jr .handle_duel_finished

.active_duelist_won_battle
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr nz, .opponent_won_battle
.player_won_battle
	xor a ; DUEL_WIN
	ld [wDuelResult], a
	ld a, $5d
	ld c, MUSIC_MATCH_VICTORY
	ldtx hl, WonDuelText
	jr .handle_duel_finished

.active_duelist_lost_batte
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr nz, .player_won_battle
.opponent_won_battle
	ld a, DUEL_LOSS
	ld [wDuelResult], a
	ld a, $5e
	ld c, MUSIC_MATCH_LOSS
	ldtx hl, LostDuelText

.handle_duel_finished
	call Func_3b6a
	ld a, c
	call PlaySong
	ld a, OPPONENT_TURN
	ldh [hWhoseTurn], a
	call DrawWideTextBox_PrintText
	call EnableLCD
.wait_song
	call DoFrame
	call AssertSongFinished
	or a
	jr nz, .wait_song
	ld a, [wDuelFinished]
	cp TURN_PLAYER_TIED
	jr z, .tied_battle
	call Func_39fc
	call WaitForWideTextBoxInput
	call Func_3b31
	call ResetSerial
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	ret

.tied_battle
	call WaitForWideTextBoxInput
	call Func_3b31
	ld a, [wDuelTheme]
	call PlaySong
	ldtx hl, StartSuddenDeathMatchText
	call DrawWideTextBox_WaitForInput
	ld a, 1
	ld [wDuelInitialPrizes], a
	call InitVariablesToBeginDuel
	ld a, [wDuelType]
	cp DUELTYPE_LINK
	jr z, .link_duel
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	call Func_4b60
	jp MainDuelLoop
.link_duel
	call ExchangeRNG
	ld h, PLAYER_TURN
	ld a, [wSerialOp]
	cp $29
	jr z, .got_turn
	ld h, OPPONENT_TURN
.got_turn
	ld a, h
	ldh [hWhoseTurn], a
	call Func_4b60
	jp nc, MainDuelLoop
	ret
; 0x420b

; empty the screen, and setup text and graphics for a duel
SetupDuel: ; 420b (1:420b)
	xor a ; SYM_SPACE
	ld [wTileMapFill], a
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadSymbolsFont
	call SetDefaultPalettes
	lb de, $38, $9f
	call SetupText
	call EnableLCD
	ret
; 0x4225

; handle the turn of the duelist identified by hWhoseTurn.
; if player's turn, display the animation of the player drawing the card at
; hTempCardIndex_ff98, and save the duel state to SRAM.
HandleTurn: ; 4225 (1:4225)
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	ld [wDuelistType], a
	ld a, [wDuelTurns]
	cp 2
	jr c, .skip_let_evolve ; jump if it's the turn holder's first turn
	call SetAllPlayAreaPokemonCanEvolve
.skip_let_evolve
	call InitVariablesToBeginTurn
	call DisplayDrawOneCardScreen
	call DrawCardFromDeck
	jr nc, .deck_not_empty
	ld a, TURN_PLAYER_LOST
	ld [wDuelFinished], a
	ret

.deck_not_empty
	ldh [hTempCardIndex_ff98], a
	call AddCardToHand
	ld a, [wDuelistType]
	cp DUELIST_TYPE_PLAYER
	jr z, .player_turn

; opponent's turn
	call SwapTurn
	call IsClairvoyanceActive
	call SwapTurn
	call c, DisplayPlayerDrawCardScreen
	jr DuelMainInterface

; player's turn
.player_turn
	call DisplayPlayerDrawCardScreen
	call SaveDuelStateToSRAM
;	fallthrough

Func_4268:
	ld a, $06
	call DoPracticeDuelAction
;	fallthrough

; print the main interface during a duel, including background, Pokemon, HUDs and a text box.
; the bottom text box changes depending on whether the turn belongs to the player (show the duel menu),
; an AI opponent (print "Waiting..." and a reduced menu) or a link opponent (print "<Duelist> is thinking").
DuelMainInterface: ; 426d (1:426d)
	call DrawDuelMainScene
	ld a, [wDuelistType]
	cp DUELIST_TYPE_PLAYER
	jr z, PrintDuelMenuAndHandleInput
	cp DUELIST_TYPE_LINK_OPP
	jp z, Func_6911
	; DUELIST_TYPE_AI_OPP
	xor a
	ld [wVBlankCounter], a
	ld [wSkipDuelistIsThinkingDelay], a
	ldtx hl, DuelistIsThinkingText
	call DrawWideTextBox_PrintTextNoDelay
	call Func_2bbf
	ld a, $ff
	ld [wPlayerAttackingCardIndex], a
	ld [wPlayerAttackingMoveIndex], a
	ret

PrintDuelMenuAndHandleInput: ; 4295 (1:4295)
	call DrawWideTextBox
	ld hl, DuelMenuData
	call PlaceTextItems
.menu_items_printed
	call SaveDuelData
	ld a, [wDuelFinished]
	or a
	ret nz
	ld a, [wCurrentDuelMenuItem]
	call SetMenuItem

.handle_input
	call DoFrame
	ldh a, [hKeysHeld]
	and B_BUTTON
	jr z, .b_not_held
	ldh a, [hKeysPressed]
	bit D_UP_F, a
	jr nz, DuelMenuShortcut_OpponentPlayArea
	bit D_DOWN_F, a
	jr nz, DuelMenuShortcut_PlayerPlayArea
	bit D_LEFT_F, a
	jr nz, DuelMenuShortcut_PlayerDiscardPile
	bit D_RIGHT_F, a
	jr nz, DuelMenuShortcut_OpponentDiscardPile
	bit START_F, a
	jp nz, DuelMenuShortcut_OpponentActivePokemon

.b_not_held
	ldh a, [hKeysPressed]
	and START
	jp nz, DuelMenuShortcut_PlayerActivePokemon
	ldh a, [hKeysPressed]
	bit SELECT_F, a
	jp nz, DuelMenuShortcut_BothActivePokemon
	ld a, [wcbe7]
	or a
	jr nz, .handle_input
	call HandleDuelMenuInput
	ld a, e
	ld [wCurrentDuelMenuItem], a
	jr nc, .handle_input
	ldh a, [hCurMenuItem]
	ld hl, DuelMenuFunctionTable
	jp JumpToFunctionInTable

DuelMenuFunctionTable: ; 42f1 (1:42f1)
	dw DuelMenu_Hand
	dw DuelMenu_Attack
	dw DuelMenu_Check
	dw DuelMenu_PkmnPower
	dw DuelMenu_Retreat
	dw DuelMenu_Done

Func_42fd: ; 42fd (1:42fd)
	call DrawCardFromDeck
	call nc, AddCardToHand
	ld a, $0b
	call SetAIAction_SerialSendDuelData
	jp PrintDuelMenuAndHandleInput.menu_items_printed
; 0x430b

; triggered by pressing B + UP in the duel menu
DuelMenuShortcut_OpponentPlayArea: ; 430b (1:430b)
	call OpenOpponentPlayAreaScreen
	jp DuelMainInterface

; triggered by pressing B + DOWN in the duel menu
DuelMenuShortcut_PlayerPlayArea: ; 4311 (1:4311)
	call OpenPlayAreaScreen
	jp DuelMainInterface

; triggered by pressing B + LEFT in the duel menu
DuelMenuShortcut_OpponentDiscardPile: ; 4317 (1:4317)
	call OpenOpponentDiscardPileScreen
	jp c, PrintDuelMenuAndHandleInput
	jp DuelMainInterface

; triggered by pressing B + RIGHT in the duel menu
DuelMenuShortcut_PlayerDiscardPile: ; 4320 (1:4320)
	call OpenPlayerDiscardPileScreen
	jp c, PrintDuelMenuAndHandleInput
	jp DuelMainInterface

; draw the opponent's play area screen
OpenOpponentPlayAreaScreen: ; 4329 (1:4329)
	call SwapTurn
	call OpenPlayAreaScreen
	call SwapTurn
	ret

; draw the turn holder's play area screen
OpenPlayAreaScreen: ; 4333 (1:4333)
	call HasAlivePokemonInPlayArea
	jp OpenPlayAreaScreenForViewing

; draw the opponent's discard pile screen
OpenOpponentDiscardPileScreen: ; 4339 (1:4339)
	call SwapTurn
	call OpenDiscardPileScreen
	jp SwapTurn

; draw the player's discard pile screen
OpenPlayerDiscardPileScreen: ; 4342 (1:4342)
	jp OpenDiscardPileScreen

Func_4345: ; 4345 (1:4345)
	call SwapTurn
	call Func_434e
	jp SwapTurn
; 0x434e

Func_434e: ; 434e (1:434e)
	call CreateHandCardList
	jr c, .no_cards_in_hand
	call InitAndDrawCardListScreenLayout
	ld a, START + A_BUTTON
	ld [wWatchedButtons_cbd6], a
	jp Func_55f0
.no_cards_in_hand
	ldtx hl, NoCardsInHandText
	jp DrawWideTextBox_WaitForInput
; 0x4364

; triggered by pressing B + START in the duel menu
DuelMenuShortcut_OpponentActivePokemon: ; 4364 (1:4364)
	call SwapTurn
	call OpenActivePokemonScreen
	call SwapTurn
	jp DuelMainInterface
; 0x4370

; triggered by pressing START in the duel menu
DuelMenuShortcut_PlayerActivePokemon: ; 4370 (1:4370)
	call OpenActivePokemonScreen
	jp DuelMainInterface
; 0x4376

; draw the turn holder's active Pokemon screen if it exists
OpenActivePokemonScreen: ; 4376 (1:4376)
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	ret z
	call GetCardIDFromDeckIndex
	call LoadCardDataToBuffer1_FromCardID
	ld hl, wCurPlayAreaSlot
	xor a
	ld [hli], a
	ld [hl], a ; wCurPlayAreaY
	call Func_576a
	ret
; 0x438e

; triggered by selecting the "Pkmn Power" item in the duel menu
DuelMenu_PkmnPower: ; 438e (1:438e)
	call $6431
	jp c, DuelMainInterface
	call UseAttackOrPokemonPower
	jp DuelMainInterface

; triggered by selecting the "Done" item in the duel menu
DuelMenu_Done: ; 439a (1:439a)
	ld a, $08
	call DoPracticeDuelAction
	jp c, Func_4268
	ld a, $05
	call SetAIAction_SerialSendDuelData
	call ClearNonTurnTemporaryDuelvars
	ret

; triggered by selecting the "Retreat" item in the duel menu
DuelMenu_Retreat: ; 43ab (1:43ab)
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	and CNF_SLP_PRZ
	cp CONFUSED
	ldh [hTemp_ffa0], a
	jr nz, .not_confused
	ld a, [wGotHeadsFromConfusionCheckDuringRetreat]
	or a
	jr nz, .unable_due_to_confusion
	call CheckAbleToRetreat
	jr c, .unable_to_retreat
	call DisplayRetreatScreen
	jr c, .done
	ldtx hl, SelectPkmnOnBenchToSwitchWithActiveText
	call DrawWideTextBox_WaitForInput
	call OpenPlayAreaScreenForSelection
	jr c, .done
	ld [wBenchSelectedPokemon], a
	ld a, [wBenchSelectedPokemon]
	ldh [hTempPlayAreaLocation_ffa1], a
	ld a, $04
	call SetAIAction_SerialSendDuelData
	call AttemptRetreat
	jr nc, .done
	call DrawDuelMainScene

.unable_due_to_confusion
	ldtx hl, UnableToRetreatText
	call DrawWideTextBox_WaitForInput
	jp PrintDuelMenuAndHandleInput

.not_confused
	; note that the energy cards are discarded (DiscardRetreatCostCards), then returned
	; (ReturnRetreatCostCardsToArena), then discarded again for good (AttemptRetreat).
	; It's done this way so that the retreating Pokemon is listed with its energies updated
	; when the Play Area screen is shown to select the Pokemon to switch to. The reason why
	; AttemptRetreat is responsible for discarding the energy cards is because, if the
	; Pokemon is confused, it may not be able to retreat, so they cannot be discarded earlier.
	call CheckAbleToRetreat
	jr c, .unable_to_retreat
	call DisplayRetreatScreen
	jr c, .done
	call DiscardRetreatCostCards
	ldtx hl, SelectPkmnOnBenchToSwitchWithActiveText
	call DrawWideTextBox_WaitForInput
	call OpenPlayAreaScreenForSelection
	ld [wBenchSelectedPokemon], a
	ldh [hTempPlayAreaLocation_ffa1], a
	push af
	call ReturnRetreatCostCardsToArena
	pop af
	jp c, DuelMainInterface
	ld a, $04
	call SetAIAction_SerialSendDuelData
	call AttemptRetreat

.done
	jp DuelMainInterface

.unable_to_retreat
	call DrawWideTextBox_WaitForInput
	jp PrintDuelMenuAndHandleInput

; triggered by selecting the "Hand" item in the duel menu
DuelMenu_Hand: ; 4425 (1:4425)
	ld a, DUELVARS_NUMBER_OF_CARDS_IN_HAND
	call GetTurnDuelistVariable
	or a
	jr nz, OpenPlayerHandScreen
	ldtx hl, NoCardsInHandText
	call DrawWideTextBox_WaitForInput
	jp PrintDuelMenuAndHandleInput

; draw the screen for the player's hand and handle user input to for example check
; a card or attempt to use a card, playing the card if possible in that case.
OpenPlayerHandScreen: ; 4436 (1:4436)
	call CreateHandCardList
	call InitAndDrawCardListScreenLayout
	ldtx hl, PleaseSelectHandText
	call SetCardListInfoBoxText
	ld a, PLAY_CHECK
	ld [wCardListItemSelectionMenuType], a
.handle_input
	call Func_55f0
	push af
	ld a, [wSortCardListByID]
	or a
	call nz, SortHandCardsByID
	pop af
	jp c, DuelMainInterface
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, [wLoadedCard1Type]
	ld c, a
	bit TYPE_TRAINER_F, c
	jr nz, .trainer_card
	bit TYPE_ENERGY_F, c
	jr nz, UseEnergyCard
	call UsePokemonCard
	jr c, ReloadCardListScreen ; jump if card not played
	jp DuelMainInterface
.trainer_card
	call UseTrainerCard
	jr c, ReloadCardListScreen ; jump if card not played
	jp DuelMainInterface

; use the energy card with deck index at hTempCardIndex_ff98
; c contains the type of energy card being played
UseEnergyCard: ; 4477 (1:4477)
	ld a, c
	cp TYPE_ENERGY_WATER
	jr nz, .not_water_energy
	call IsRainDanceActive
	jr c, .rain_dance_active

.not_water_energy
	ld a, [wAlreadyPlayedEnergy]
	or a
	jr nz, .already_played_energy
	call HasAlivePokemonInPlayArea
	call OpenPlayAreaScreenForSelection ; choose card to play energy card on
	jp c, DuelMainInterface ; exit if no card was chosen
.play_energy_set_played
	ld a, 1
	ld [wAlreadyPlayedEnergy], a
.play_energy
	ldh a, [hTempPlayAreaLocation_ff9d]
	ldh [hTempPlayAreaLocation_ffa1], a
	ld e, a
	ldh a, [hTempCardIndex_ff98]
	ldh [hTemp_ffa0], a
	call PutHandCardInPlayArea
	call PrintPlayAreaCardList_EnableLCD
	ld a, $03
	call SetAIAction_SerialSendDuelData
	call PrintAttachedEnergyToPokemon
	jp DuelMainInterface

.rain_dance_active
	call HasAlivePokemonInPlayArea
	call OpenPlayAreaScreenForSelection ; choose card to play energy card on
	jp c, DuelMainInterface ; exit if no card was chosen
	call CheckRainDanceScenario
	jr c, .play_energy
	ld a, [wAlreadyPlayedEnergy]
	or a
	jr z, .play_energy_set_played
	ldtx hl, MayOnlyAttachOneEnergyCardText
	call DrawWideTextBox_WaitForInput
	jp OpenPlayerHandScreen

.already_played_energy
	ldtx hl, MayOnlyAttachOneEnergyCardText
	call DrawWideTextBox_WaitForInput
;	fallthrough

; reload the card list screen after the card trying to play couldn't be played
ReloadCardListScreen: ; 44d2 (1:44d2)
	call CreateHandCardList
	; skip doing the things that have already been done when initially opened
	call DrawCardListScreenLayout
	jp OpenPlayerHandScreen.handle_input
; 0x44db

; use a basic Pokemon card on the arena or bench, or place an stage 1 or 2
; Pokemon card over a Pokemon card already in play to evolve it.
; the card to use is loaded in wLoadedCard1 and its deck index is at hTempCardIndex_ff98.
; return nc if the card was played, carry if it wasn't.
UsePokemonCard: ; 44db (1:44db)
	ld a, [wLoadedCard1Stage]
	or a ; BASIC
	jr nz, .try_evolve ; jump if the card being played is a Stage 1 or 2 Pokemon
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	cp MAX_PLAY_AREA_POKEMON
	jr nc, .no_space
	ldh a, [hTempCardIndex_ff98]
	ldh [hTemp_ffa0], a
	call PutHandPokemonCardInPlayArea
	ldh [hTempPlayAreaLocation_ff9d], a
	add DUELVARS_ARENA_CARD_STAGE
	call GetTurnDuelistVariable
	ld [hl], BASIC
	ld a, $01
	call SetAIAction_SerialSendDuelData
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, 20
	call CopyCardNameAndLevel
	ld [hl], $00
	ld hl, $0000
	call LoadTxRam2
	ldtx hl, PlacedOnTheBenchText
	call DrawWideTextBox_WaitForInput
	call Func_161e
	or a
	ret

.no_space
	ldtx hl, NoSpaceOnTheBenchText
	call DrawWideTextBox_WaitForInput
	scf
	ret

.try_evolve
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	ld c, a
	ldh a, [hTempCardIndex_ff98]
	ld d, a
	ld e, PLAY_AREA_ARENA
	push de
	push bc
.next_play_area_pkmn
	push de
	call CheckIfCanEvolveInto
	pop de
	jr nc, .can_evolve
	inc e
	dec c
	jr nz, .next_play_area_pkmn
	pop bc
	pop de
.find_cant_evolve_reason_loop
	push de
	call CheckIfCanEvolveInto
	pop de
	ldtx hl, CantEvolvePokemonInSameTurnItsPlacedText
	jr nz, .cant_same_turn
	inc e
	dec c
	jr nz, .find_cant_evolve_reason_loop
	ldtx hl, NoPokemonCapableOfEvolvingText
.cant_same_turn
	; don't bother opening the selection screen if there are no pokemon capable of evolving
	call DrawWideTextBox_WaitForInput
	scf
	ret

.can_evolve
	pop bc
	pop de
	call IsPrehistoricPowerActive
	jr c, .prehistoric_power
	call HasAlivePokemonInPlayArea
.try_evolve_loop
	call OpenPlayAreaScreenForSelection
	jr c, .done
	ldh a, [hTempCardIndex_ff98]
	ldh [hTemp_ffa0], a
	ldh a, [hTempPlayAreaLocation_ff9d]
	ldh [hTempPlayAreaLocation_ffa1], a
	call EvolvePokemonCard
	jr c, .try_evolve_loop ; jump if evolution wasn't successsful somehow
	ld a, $02
	call SetAIAction_SerialSendDuelData
	call PrintPlayAreaCardList_EnableLCD
	call PrintPokemonEvolvedIntoPokemon
	call Func_161e
.done
	or a
	ret

.prehistoric_power
	call DrawWideTextBox_WaitForInput
	scf
	ret
; 0x4585

; triggered by selecting the "Check" item in the duel menu
DuelMenu_Check: ; 4585 (1:4585)
	call Func_3b31
	call Func_3096
	jp DuelMainInterface

; triggered by pressing SELECT in the duel menu
DuelMenuShortcut_BothActivePokemon: ; 458e (1:458e)
	call Func_3b31
	call Func_4597
	jp DuelMainInterface
; 0x4597

Func_4597: ; 4597 (1:4597)
	call Func_30a6
	ret c
	call Func_45a9
	ret c
	call SwapTurn
	call Func_45a9
	call SwapTurn
	ret
; 0x45a9

Func_45a9: ; 45a9 (1:45a9)
	call HasAlivePokemonInPlayArea
	ld a, $02
	ld [wcbd4], a
	call OpenPlayAreaScreenForViewing
	ldh a, [hKeysPressed]
	and B_BUTTON
	ret z
	scf
	ret
; 0x45bb

; check if the turn holder's arena Pokemon is unable to retreat due to
; some status condition or due the bench containing no alive Pokemon.
; return carry if unable, nc if able.
CheckAbleToRetreat: ; 45bb (1:45bb)
	call CheckCantRetreatDueToAcid
	ret c
	call CheckIfActiveCardParalyzedOrAsleep
	ret c
	call HasAlivePokemonOnBench
	jr c, .unable_to_retreat
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call GetCardIDFromDeckIndex
	call LoadCardDataToBuffer1_FromCardID
	ld a, [wLoadedCard1Type]
	cp TYPE_TRAINER
	jr z, .unable_to_retreat
	call CheckIfEnoughEnergiesToRetreat
	jr c, .not_enough_energies
	or a
	ret
.not_enough_energies
	ld a, [wEnergyCardsRequiredToRetreat]
	ld l, a
	ld h, $00
	call LoadTxRam3
	ldtx hl, EnergyCardsRequiredToRetreatText
	jr .done
.unable_to_retreat
	ldtx hl, UnableToRetreatText
.done
	scf
	ret
; 0x45f4

; check if the turn holder's arena Pokemon has enough energies attached to it
; in order to retreat. Return carry if it doesn't.
; load amount of energies required to wEnergyCardsRequiredToRetreat.
CheckIfEnoughEnergiesToRetreat: ; 45f4 (1:45f4)
	ld e, PLAY_AREA_ARENA
	call GetPlayAreaCardAttachedEnergies
	xor a
	ldh [hTempPlayAreaLocation_ff9d], a
	call GetPlayAreaCardRetreatCost
	ld [wEnergyCardsRequiredToRetreat], a
	ld c, a
	ld a, [wTotalAttachedEnergies]
	cp c
	ret c
	ld [wcbcd], a
	ld a, c
	ld [wEnergyCardsRequiredToRetreat], a
	or a
	ret
; 0x4611

; display the screen that prompts the player to select energy cards to discard
; in order to retreat a Pokemon card. also handle input in order to display
; the amount of energy cards already selected, and return whenever enough
; energy cards have been selected or if the player declines to retreat.
DisplayRetreatScreen: ; 4611 (1:4611)
	ld a, $ff
	ldh [hTempRetreatCostCards], a
	ld a, [wEnergyCardsRequiredToRetreat]
	or a
	ret z ; return if no energy cards are required at all
	xor a
	ld [wcbcd], a
	call CreateArenaOrBenchEnergyCardList
	call SortCardsInDuelTempListByID
	ld a, LOW(hTempRetreatCostCards)
	ld [wcbd5], a
	xor a
	call DisplayEnergyDiscardScreen
	ld a, [wEnergyCardsRequiredToRetreat]
	ld [wcbfa], a
.select_energies_loop
	ld a, [wcbcd]
	ld [wcbfb], a
	call HandleEnergyDiscardMenuInput
	ret c
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer2_FromDeckIndex
	; append selected energy card to hTempRetreatCostCards
	ld hl, wcbd5
	ld c, [hl]
	inc [hl]
	ldh a, [hTempCardIndex_ff98]
	ld [$ff00+c], a
	; accumulate selected energy card
	ld c, 1
	ld a, [wLoadedCard2Type]
	cp TYPE_ENERGY_DOUBLE_COLORLESS
	jr nz, .not_double
	inc c
.not_double
	ld hl, wcbcd
	ld a, [hl]
	add c
	ld [hl], a
	ld hl, wEnergyCardsRequiredToRetreat
	cp [hl]
	jr nc, .enough
	; not enough energies selected yet
	ldh a, [hTempCardIndex_ff98]
	call RemoveCardFromDuelTempList
	call DisplayEnergyDiscardMenu
	jr .select_energies_loop
.enough
	; terminate hTempRetreatCostCards array with $ff
	ld a, [wcbd5]
	ld c, a
	ld a, $ff
	ld [$ff00+c], a
	or a
	ret
; 0x4673

; display the screen that prompts the player to select energy cards to discard
; in order to retreat a Pokemon card or use an attack like Ember. includes the
; card's information and a menu to select the attached energy cards to discard.
; input: a = PLAY_AREA_* of the Pokemon trying to discard energies from.
DisplayEnergyDiscardScreen: ; 4673 (1:4673)
	ld [wcbe0], a
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelFaceDownCardTiles
	ld a, [wcbe0]
	ld hl, wCurPlayAreaSlot
	ld [hli], a
	ld [hl], 0 ; wCurPlayAreaY
	call PrintPlayAreaCardInformation
	xor a
	ld [wcbfb], a
	inc a
	ld [wcbfa], a
;	fallthrough

; display the menu that belongs to the energy discard screen that lets the player
; select energy cards attached to a Pokemon card in order to retreat it or use
; an attack like Ember, Flamethrower...
DisplayEnergyDiscardMenu: ; 4693 (1:4693)
	lb de, 0, 3
	lb bc, 20, 10
	call DrawRegularTextBox
	ldtx hl, ChooseEnergyCardToDiscardText
	call DrawWideTextBox_PrintTextNoDelay
	call EnableLCD
	call CountCardsInDuelTempList
	ld hl, EnergyDiscardCardListParameters
	lb de, 0, 0 ; initial page scroll offset, initial item (in the visible page)
	call PrintCardListItems
	ld a, 4
	ld [wCardListIndicatorYPosition], a
	ret
; 0x46b7

; if [wcbfa] non-0:
   ; prints "[wcbfb]/[wcbfa]" at 16,16, where [wcbfb] is the total amount
   ; of energy cards already selected to discard, and [wcbfa] is the total
   ; amount of energies that are required to discard.
; if [wcbfa] == 0:
	; prints only "[wcbfb]"
HandleEnergyDiscardMenuInput: ; 46b7 (1:46b7)
	lb bc, 16, 16
	ld a, [wcbfa]
	or a
	jr z, .print_single_number
	ld a, [wcbfb]
	add SYM_0
	call WriteByteToBGMap0
	inc b
	ld a, SYM_SLASH
	call WriteByteToBGMap0
	inc b
	ld a, [wcbfa]
	add SYM_0
	call WriteByteToBGMap0
	jr .wait_input
.print_single_number
	ld a, [wcbfb]
	inc b
	call WriteTwoDigitNumberInTxSymbolFormat
.wait_input
	call DoFrame
	call HandleCardListInput
	jr nc, .wait_input
	cp $ff ; B pressed?
	jr z, .return_carry
	call GetCardInDuelTempList_OnlyDeckIndex
	or a
	ret
.return_carry
	scf
	ret
; 0x46f3

EnergyDiscardCardListParameters:
	db 1, 5 ; cursor x, cursor y
	db 4 ; item x
	db 14 ; maximum length, in tiles, occupied by the name and level string of each card in the list
	db 4 ; number of items selectable without scrolling
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw $0000 ; function pointer if non-0

; triggered by selecting the "Attack" item in the duel menu
DuelMenu_Attack: ; 46fc (1:46fc)
	call HandleCantAttackSubstatus
	jr c, .alert_cant_attack_and_cancel_menu
	call CheckIfActiveCardParalyzedOrAsleep
	jr nc, .can_attack
.alert_cant_attack_and_cancel_menu
	call DrawWideTextBox_WaitForInput
	jp PrintDuelMenuAndHandleInput

.can_attack
	xor a
	ld [wSelectedDuelSubMenuItem], a
.try_open_attack_menu
	call LoadPokemonMovesToDuelTempList
	or a
	jr nz, .open_attack_menu
	ldtx hl, NoSelectableAttackText
	call DrawWideTextBox_WaitForInput
	jp PrintDuelMenuAndHandleInput

.open_attack_menu
	push af
	ld a, [wSelectedDuelSubMenuItem]
	ld hl, AttackMenuParameters
	call InitializeMenuParameters
	pop af
	ld [wNumMenuItems], a
	ldh a, [hWhoseTurn]
	ld h, a
	ld l, DUELVARS_ARENA_CARD
	ld a, [hl]
	call LoadCardDataToBuffer1_FromDeckIndex

.wait_for_input
	call DoFrame
	ldh a, [hKeysPressed]
	and START
	jr nz, .display_selected_move_info
	call HandleMenuInput
	jr nc, .wait_for_input
	cp -1 ; was B pressed?
	jp z, PrintDuelMenuAndHandleInput
	ld [wSelectedDuelSubMenuItem], a
	call CheckIfEnoughEnergiesToMove
	jr nc, .enough_energy
	ldtx hl, NotEnoughEnergyCardsText
	call DrawWideTextBox_WaitForInput
	jr .try_open_attack_menu

.enough_energy
	ldh a, [hCurMenuItem]
	add a
	ld e, a
	ld d, $00
	ld hl, wDuelTempList
	add hl, de
	ld d, [hl] ; card's deck index (0 to 59)
	inc hl
	ld e, [hl] ; attack index (0 or 1)
	call CopyMoveDataAndDamage_FromDeckIndex
	call HandleAmnesiaSubstatus
	jr c, .cannot_use_due_to_amnesia
	ld a, $07
	call DoPracticeDuelAction
	jp c, Func_4268
	call UseAttackOrPokemonPower
	jp c, DuelMainInterface
	ret

.cannot_use_due_to_amnesia
	call DrawWideTextBox_WaitForInput
	jr .try_open_attack_menu

.display_selected_move_info
	call Func_478b
	call DrawDuelMainScene
	jp .try_open_attack_menu

Func_478b: ; 478b (1:478b)
	ld a, CARDPAGE_POKEMON_OVERVIEW
	ld [wCardPageNumber], a
	xor a
	ld [wCurPlayAreaSlot], a
	call EmptyScreen
	call Func_3b31
	ld de, v0Tiles1 + $20 tiles
	call LoadLoaded1CardGfx
	call SetOBP1OrSGB3ToCardPalette
	call SetBGP6OrSGB3ToCardPalette
	call FlushAllPalettesOrSendPal23Packet
	lb de, $38, $30 ; X Position and Y Position of top-left corner
	call PlaceCardImageOAM
	lb de, 6, 4
	call ApplyBGP6OrSGB3ToCardImage
	ldh a, [hCurMenuItem]
	ld [wSelectedDuelSubMenuItem], a
	add a
	ld e, a
	ld d, $00
	ld hl, wDuelTempList + 1
	add hl, de
	ld a, [hl]
	or a
	jr nz, .asm_47c9
	xor a
	jr .asm_47cb

.asm_47c9
	ld a, $02

.asm_47cb
	ld [wcc04], a

.asm_47ce
	call Func_47ec
	call EnableLCD

.asm_47d4
	call DoFrame
	ldh a, [hDPadHeld]
	and D_RIGHT | D_LEFT
	jr nz, .asm_47ce
	ldh a, [hKeysPressed]
	and A_BUTTON | B_BUTTON
	jr z, .asm_47d4
	ret

AttackMenuParameters:
	db 1, 13 ; cursor x, cursor y
	db 2 ; y displacement between items
	db 2 ; number of items
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw $0000 ; function pointer if non-0

Func_47ec: ; $47ec (1:47ec)
	ld a, [wcc04]
	ld hl, $47f5
	jp JumpToFunctionInTable

PtrTable_47f5: ; $47f5 (1:47f5)
	dw Func_47fd
	dw Func_4802
	dw Func_480d
	dw Func_4812

Func_47fd: ; $47fd (1:47fd)
	call $5d1f
	jr Func_481b

Func_4802: ; $4802 (1:4802)
	ld hl, wLoadedCard1Move1Description + 2
	ld a, [hli]
	or [hl]
	ret z
	call $5d27
	jr Func_481b

Func_480d: ; $480d (1:480d)
	call $5d2f
	jr Func_481b

Func_4812: ; $4812 (1:4812)
	ld hl, wLoadedCard1Move2Description + 2
	ld a, [hli]
	or [hl]
	ret z
	call $5d37

Func_481b: ; $481b (1:481b)
	ld hl, wcc04
	ld a, $01
	xor [hl]
	ld [hl], a
	ret

; copies the following to the wDuelTempList buffer:
;   if pokemon's second moveslot is empty: <card_no>, 0
;   else: <card_no>, 0, <card_no>, 1
LoadPokemonMovesToDuelTempList: ; 4823 (1:4823)
	call DrawWideTextBox
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	ldh [hTempCardIndex_ff98], a
	call LoadCardDataToBuffer1_FromDeckIndex
	ld c, $00
	ld b, $0d
	ld hl, wDuelTempList
	xor a
	ld [wCardPageNumber], a
	ld de, wLoadedCard1Move1Name
	call CheckIfMoveExists
	jr c, .check_for_second_attack_slot
	ldh a, [hTempCardIndex_ff98]
	ld [hli], a
	xor a
	ld [hli], a
	inc c
	push hl
	push bc
	ld e, b
	ld hl, wLoadedCard1Move1Name
	call Func_5c33
	pop bc
	pop hl
	inc b
	inc b

.check_for_second_attack_slot
	ld de, wLoadedCard1Move2Name
	call CheckIfMoveExists
	jr c, .finish_loading_attacks
	ldh a, [hTempCardIndex_ff98]
	ld [hli], a
	ld a, $01
	ld [hli], a
	inc c
	push hl
	push bc
	ld e, b
	ld hl, wLoadedCard1Move2Name
	call Func_5c33
	pop bc
	pop hl

.finish_loading_attacks
	ld a, c
	ret

; given de = wLoadedCard*Move*Name, return carry if the move is a
; Pkmn Power or the moveslot is empty.
CheckIfMoveExists: ; 4872 (1:4872)
	push hl
	push de
	push bc
	ld a, [de]
	ld c, a
	inc de
	ld a, [de]
	or c
	jr z, .return_no_move_found
	ld hl, CARD_DATA_MOVE1_CATEGORY - (CARD_DATA_MOVE1_NAME + 1)
	add hl, de
	ld a, [hl]
	and $ff ^ RESIDUAL
	cp POKEMON_POWER
	jr z, .return_no_move_found
	or a
.return
	pop bc
	pop de
	pop hl
	ret
.return_no_move_found
	scf
	jr .return

; check if the arena pokemon card has enough energy attached to it
; in order to use the selected move.
; returns: carry if not enough energy, nc if enough energy.
CheckIfEnoughEnergiesToMove: ; 488f (1:488f)
	push hl
	push bc
	ld e, PLAY_AREA_ARENA
	call GetPlayAreaCardAttachedEnergies
	call HandleEnergyBurn
	ldh a, [hCurMenuItem]
	add a
	ld e, a
	ld d, $0
	ld hl, wDuelTempList
	add hl, de
	ld d, [hl] ; card's deck index (0 to 59)
	inc hl
	ld e, [hl] ; attack index (0 or 1)
	call _CheckIfEnoughEnergiesToMove
	pop bc
	pop hl
	ret
; 0x48ac

; check if a pokemon card has enough energy attached to it in order to use a move
; input:
;   d = deck index of card (0 to 59)
;   e = attack index (0 or 1)
;   wAttachedEnergies and wTotalAttachedEnergies
; returns: carry if not enough energy, nc if enough energy.
_CheckIfEnoughEnergiesToMove: ; 48ac (1:48ac)
	push de
	ld a, d
	call LoadCardDataToBuffer1_FromDeckIndex
	pop bc
	push bc
	ld de, wLoadedCard1Move1Energy
	ld a, c
	or a
	jr z, .got_move
	ld de, wLoadedCard1Move2Energy

.got_move
	ld hl, CARD_DATA_MOVE1_NAME - CARD_DATA_MOVE1_ENERGY
	add hl, de
	ld a, [hli]
	or [hl]
	jr z, .not_usable_or_not_enough_energies
	ld hl, CARD_DATA_MOVE1_CATEGORY - CARD_DATA_MOVE1_ENERGY
	add hl, de
	ld a, [hl]
	cp POKEMON_POWER
	jr z, .not_usable_or_not_enough_energies
	xor a
	ld [wAttachedEnergiesAccum], a
	ld hl, wAttachedEnergies
	ld c, (NUM_COLORED_TYPES) / 2

.next_energy_type_pair
	ld a, [de]
	swap a
	call CheckIfEnoughEnergiesOfType
	jr c, .not_usable_or_not_enough_energies
	ld a, [de]
	call CheckIfEnoughEnergiesOfType
	jr c, .not_usable_or_not_enough_energies
	inc de
	dec c
	jr nz, .next_energy_type_pair
	ld a, [de] ; colorless energy
	swap a
	and $f
	ld b, a
	ld a, [wAttachedEnergiesAccum]
	ld c, a
	ld a, [wTotalAttachedEnergies]
	sub c
	cp b
	jr c, .not_usable_or_not_enough_energies
	or a
.done
	pop de
	ret

.not_usable_or_not_enough_energies
	scf
	jr .done
; 0x4900

; given the amount of energies of a specific type required for an attack in the
; lower nybble of register a, test if the pokemon card has enough energies of that type
; to use the move. Return carry if not enough energy, nc if enough energy.
CheckIfEnoughEnergiesOfType: ; 4900 (1:4900)
	and $f
	push af
	push hl
	ld hl, wAttachedEnergiesAccum
	add [hl]
	ld [hl], a ; accumulate the amount of energies required
	pop hl
	pop af
	jr z, .enough_energies ; jump if no energies of this type are required
	cp [hl]
	; jump if the energies required of this type are not more than the amount attached
	jr z, .enough_energies
	jr c, .enough_energies
	inc hl
	scf
	ret

.enough_energies
	inc hl
	or a
	ret
; 0x4918

; return carry and the corresponding text in hl if the turn holder's
; arena Pokemon card is paralyzed or asleep.
CheckIfActiveCardParalyzedOrAsleep: ; 4918 (1:4918)
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	and CNF_SLP_PRZ
	cp PARALYZED
	jr z, .paralyzed
	cp ASLEEP
	jr z, .asleep
	or a
	ret
.paralyzed
	ldtx hl, UnableDueToParalysisText
	jr .return_with_status_condition
.asleep
	ldtx hl, UnableDueToSleepText
.return_with_status_condition
	scf
	ret

; display the animation of the turn duelist drawing a card at the beginning of the turn
; if there isn't any card left in the deck, let the player know with a text message
DisplayDrawOneCardScreen: ; 4933 (1:4933)
	ld a, 1
	push hl
	push de
	push bc
	ld [wNumCardsTryingToDraw], a
	xor a
	ld [wNumCardsBeingDrawn], a
	ld a, DUELVARS_NUMBER_OF_CARDS_NOT_IN_DECK
	call GetTurnDuelistVariable
	ld a, DECK_SIZE
	sub [hl]
	ld hl, wNumCardsTryingToDraw
	cp [hl]
	jr nc, .has_cards_left
	; trying to draw more cards than there are left in the deck
	ld [hl], a ; 0
.has_cards_left
	ld a, [wDuelDisplayedScreen]
	cp DRAW_CARDS
	jr z, .portraits_drawn
	cp SHUFFLE_DECK
	jr z, .portraits_drawn
	call EmptyScreen
	call DrawDuelistPortraitsAndNames
.portraits_drawn
	ld a, DRAW_CARDS
	ld [wDuelDisplayedScreen], a
	call PrintDeckAndHandIconsAndNumberOfCards
	ld a, [wNumCardsTryingToDraw]
	or a
	jr nz, .can_draw
	; if wNumCardsTryingToDraw set to 0 before, it's because not enough cards in deck
	ldtx hl, CannotDrawCardBecauseNoCardsInDeckText
	call DrawWideTextBox_WaitForInput
	jr .done
.can_draw
	ld l, a
	ld h, 0
	call LoadTxRam3
	ldtx hl, DrawCardsFromTheDeckText
	call DrawWideTextBox_PrintText
	call EnableLCD
.anim_drawing_cards_loop
	call Func_49a8
	ld hl, wNumCardsBeingDrawn
	inc [hl]
	call PrintNumberOfHandAndDeckCards
	ld a, [wNumCardsBeingDrawn]
	ld hl, wNumCardsTryingToDraw
	cp [hl]
	jr c, .anim_drawing_cards_loop
	ld c, 30
.wait_loop
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .done
	dec c
	jr nz, .wait_loop
.done
	pop bc
	pop de
	pop hl
	ret
; 0x49a8

Func_49a8: ; 49a8 (1:49a8)
	call Func_3b21
	ld e, $56
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .asm_49b5
	ld e, $57
.asm_49b5
	ld a, e
	call Func_3b6a
.asm_49b9
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_49c6
	call Func_3b52
	jr c, .asm_49b9
.asm_49c6
	call Func_3b31
	ret
; 0x49ca

; prints, for each duelist, the number of cards in the hand along with the
; hand icon, and the number of cards in the deck, along with the deck icon,
; according to each element's placement in the draw card(s) screen.
PrintDeckAndHandIconsAndNumberOfCards: ; 49ca (1:49ca)
	call LoadDuelDrawCardsScreenTiles
	ld hl, DeckAndHandIconsTileData
	call WriteDataBlocksToBGMap0
	ld a, [wConsole]
	cp CONSOLE_CGB
	jr nz, .not_cgb
	call BankswitchVRAM1
	ld hl, DeckAndHandIconsCGBPalData
	call WriteDataBlocksToBGMap0
	call BankswitchVRAM0
.not_cgb
	call PrintPlayerNumberOfHandAndDeckCards
	call PrintOpponentNumberOfHandAndDeckCards
	ret
; 0x49ed

; prints, for each duelist, the number of cards in the hand, and the number
; of cards in the deck, according to their placement in the draw card(s) screen.
; input: wNumCardsBeingDrawn = number of cards being drawn (in order to add
; them to the hand cards and substract them from the deck cards).
PrintNumberOfHandAndDeckCards: ; 49ed (1:49ed)
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr nz, PrintOpponentNumberOfHandAndDeckCards
;	fallthrough

PrintPlayerNumberOfHandAndDeckCards:
	ld a, [wPlayerNumberOfCardsInHand]
	ld hl, wNumCardsBeingDrawn
	add [hl]
	ld d, a
	ld a, DECK_SIZE
	ld hl, wPlayerNumberOfCardsNotInDeck
	sub [hl]
	ld hl, wNumCardsBeingDrawn
	sub [hl]
	ld e, a
	ld a, d
	lb bc, 16, 10
	call WriteTwoDigitNumberInTxSymbolFormat
	ld a, e
	lb bc, 10, 10
	jp WriteTwoDigitNumberInTxSymbolFormat

PrintOpponentNumberOfHandAndDeckCards:
	ld a, [wOpponentNumberOfCardsInHand]
	ld hl, wNumCardsBeingDrawn
	add [hl]
	ld d, a
	ld a, DECK_SIZE
	ld hl, wOpponentNumberOfCardsNotInDeck
	sub [hl]
	ld hl, wNumCardsBeingDrawn
	sub [hl]
	ld e, a
	ld a, d
	lb bc, 5, 3
	call WriteTwoDigitNumberInTxSymbolFormat
	ld a, e
	lb bc, 11, 3
	jp WriteTwoDigitNumberInTxSymbolFormat
; 0x4a35

DeckAndHandIconsTileData:
; x, y, tiles[], 0
	db  4,  3, SYM_CROSS, 0 ; x for opponent's hand
	db 10,  3, SYM_CROSS, 0 ; x for opponent's deck
	db  8,  2, $f4, $f5,  0 ; opponent's deck icon
	db  8,  3, $f6, $f7,  0 ; opponent's deck icon
	db  2,  2, $f8, $f9,  0 ; opponent's hand icon
	db  2,  3, $fa, $fb,  0 ; opponent's hand icon
	db  9, 10, SYM_CROSS, 0 ; x for player's deck
	db 15, 10, SYM_CROSS, 0 ; x for player's hand
	db  7,  9, $f4, $f5,  0 ; player's deck icon
	db  7, 10, $f6, $f7,  0 ; player's deck icon
	db 13,  9, $f8, $f9,  0 ; player's hand icon
	db 13, 10, $fa, $fb,  0 ; player's hand icon
	db $ff

DeckAndHandIconsCGBPalData:
; x, y, pals[], 0
	db  8,  2, $02, $02, 0
	db  8,  3, $02, $02, 0
	db  2,  2, $02, $02, 0
	db  2,  3, $02, $02, 0
	db  7,  9, $02, $02, 0
	db  7, 10, $02, $02, 0
	db 13,  9, $02, $02, 0
	db 13, 10, $02, $02, 0
	db $ff

; draw the portraits of the two duelists and print their names.
; also draw an horizontal line separating the two sides.
DrawDuelistPortraitsAndNames: ; 4a97 (1:4a97)
	call LoadSymbolsFont
	; player's name
	ld de, wDefaultText
	push de
	call CopyPlayerName
	lb de, 0, 11
	call InitTextPrinting
	pop hl
	call ProcessText
	; player's portrait
	lb bc, 0, 5
	call Func_3e10
	; opponent's name (aligned to the right)
	ld de, wDefaultText
	push de
	call CopyOpponentName
	pop hl
	call GetTextSizeInTiles
	push hl
	add SCREEN_WIDTH
	ld d, a
	ld e, 0
	call InitTextPrinting
	pop hl
	call ProcessText
	; opponent's portrait
	ld a, [wOpponentPortrait]
	lb bc, 13, 1
	call Func_3e2a
	; middle line
	call DrawDuelHorizontalSeparator
	ret
; 0x4ad6

; print the number of prizes left, of active Pokemon, and of cards left in the deck
; of both duelists. this is called when the duel ends.
PrintDuelResultStats: ; 4ad6 (1:4ad6)
	lb de, 8, 8
	call PrintDuelistResultStats
	call SwapTurn
	lb de, 1, 1
	call PrintDuelistResultStats
	call SwapTurn
	ret
; 0x4ae9

; print, at d,e, the number of prizes left, of active Pokemon, and of cards left in
; the deck of the turn duelist. b,c are used throughout as input coords for
; WriteTwoDigitNumberInTxSymbolFormat, and d,e for InitTextPrinting_ProcessTextFromID.
PrintDuelistResultStats: ; 4ae9 (1:4ae9)
	call SetNoLineSeparation
	ldtx hl, PrizesLeftActivePokemonCardsInDeckText
	call InitTextPrinting_ProcessTextFromID
	call SetOneLineSeparation
	ld c, e
	ld a, d
	add 7
	ld b, a
	inc a
	inc a
	ld d, a
	call CountPrizes
	call .print_x_cards
	inc e
	inc c
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	ldtx hl, YesText
	or a
	jr nz, .pkmn_in_play_area
	ldtx hl, NoneText
.pkmn_in_play_area
	dec d
	call InitTextPrinting_ProcessTextFromID
	inc e
	inc d
	inc c
	ld a, DUELVARS_NUMBER_OF_CARDS_NOT_IN_DECK
	call GetTurnDuelistVariable
	ld a, DECK_SIZE
	sub [hl]
.print_x_cards
	call WriteTwoDigitNumberInTxSymbolFormat
	ldtx hl, CardsText
	call InitTextPrinting_ProcessTextFromID
	ret
; 0x4b2c

; display the animation of the player drawing the card at hTempCardIndex_ff98
DisplayPlayerDrawCardScreen: ; 4b2c (1:4b2c)
	ldtx hl, YouDrewText
	ldh a, [hTempCardIndex_ff98]
;	fallthrough

; display card detail when a card is drawn or played
; hl is text to display
; a is the card's deck index
DisplayCardDetailScreen: ; 4b31 (1:4b31)
	call LoadCardDataToBuffer1_FromDeckIndex
	call _DisplayCardDetailScreen
	ret
; 0x4b38

Func_4b38: ; 4b38 (1:4b38)
	ld a, [wDuelTempList]
	cp $ff
	ret z
	call InitAndDrawCardListScreenLayout
	call CountCardsInDuelTempList ; list length
	ld hl, CardListParameters ; other list params
	lb de, 0, 0 ; initial page scroll offset, initial item (in the visible page)
	call PrintCardListItems
	ldtx hl, TheCardYouReceivedText
	lb de, 1, 1
	call InitTextPrinting
	call PrintTextNoDelay
	ldtx hl, YouReceivedTheseCardsText
	call DrawWideTextBox_WaitForInput
	ret
; 0x4b60

Func_4b60: ; 4b60 (1:4b60)
	call InitializeDuelVariables
	call SwapTurn
	call InitializeDuelVariables
	call SwapTurn
	call Func_4e84
	call ShuffleDeckAndDrawSevenCards
	ldh [hTemp_ffa0], a
	call SwapTurn
	call ShuffleDeckAndDrawSevenCards
	call SwapTurn
	ld c, a
	ldh a, [hTemp_ffa0]
	ld b, a
	and c
	jr nz, .hand_cards_ok
	ld a, b
	or c
	jr z, .neither_drew_basic_pkmn
	ld a, b
	or a
	jr nz, .opp_drew_no_basic_pkmn

;.player_drew_no_basic_pkmn
.ensure_player_basic_pkmn_loop
	call DisplayNoBasicPokemonInHandScreenAndText
	call InitializeDuelVariables
	call Func_4e6e
	call ShuffleDeckAndDrawSevenCards
	jr c, .ensure_player_basic_pkmn_loop
	jr .hand_cards_ok

.opp_drew_no_basic_pkmn
	call SwapTurn
.ensure_opp_basic_pkmn_loop
	call DisplayNoBasicPokemonInHandScreenAndText
	call InitializeDuelVariables
	call Func_4e6e
	call ShuffleDeckAndDrawSevenCards
	jr c, .ensure_opp_basic_pkmn_loop
	call SwapTurn
	jr .hand_cards_ok

.neither_drew_basic_pkmn
	ldtx hl, NeitherPlayerHasBasicPkmnText
	call DrawWideTextBox_WaitForInput
	call DisplayNoBasicPokemonInHandScreen
	call InitializeDuelVariables
	call SwapTurn
	call DisplayNoBasicPokemonInHandScreen
	call InitializeDuelVariables
	call SwapTurn
	call PrintReturnCardsToDeckDrawAgain
	jp Func_4b60

.hand_cards_ok
	ldh a, [hWhoseTurn]
	push af
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	call Func_4cd5
	call SwapTurn
	call Func_4cd5
	call SwapTurn
	jp c, .asm_4c77
	call Func_311d
	ldtx hl, PlacingThePrizesText
	call DrawWideTextBox_WaitForInput
	call ExchangeRNG
	ld a, [wDuelInitialPrizes]
	ld l, a
	ld h, 0
	call LoadTxRam3
	ldtx hl, PleasePlacePrizesText
	call DrawWideTextBox_PrintText
	call EnableLCD
	call .asm_4c7c
	call WaitForWideTextBoxInput
	pop af
	ldh [hWhoseTurn], a
	call InitTurnDuelistPrizes
	call SwapTurn
	call InitTurnDuelistPrizes
	call SwapTurn
	call EmptyScreen
	ld a, BOXMSG_COIN_TOSS
	call DrawDuelBoxMessage
	ldtx hl, CoinTossToDecideWhoPlaysFirstText
	call DrawWideTextBox_WaitForInput
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr nz, .opponent_turn
	ld de, wDefaultText
	call CopyPlayerName
	ld hl, $0000
	call LoadTxRam2
	ldtx hl, YouPlayFirstText
	ldtx de, IfHeadsDuelistPlaysFirstText
	call TossCoin
	jr c, .play_first
	call SwapTurn
	ldtx hl, YouPlaySecondText
.play_first
	call DrawWideTextBox_WaitForInput
	call ExchangeRNG
	or a
	ret

.opponent_turn
	ld de, wDefaultText
	call CopyOpponentName
	ld hl, $0000
	call LoadTxRam2
	ldtx hl, YouPlaySecondText
	ldtx de, IfHeadsDuelistPlaysFirstText
	call TossCoin
	jr c, .play_second
	call SwapTurn
	ldtx hl, YouPlayFirstText
.play_second
	call DrawWideTextBox_WaitForInput
	call ExchangeRNG
	or a
	ret

.asm_4c77
	pop af
	ldh [hWhoseTurn], a
	scf
	ret

.asm_4c7c
	ld hl, .data_4cbd
	ld e, $34
	ld a, [wDuelInitialPrizes]
	ld d, a
.asm_4c85
	push de
	ld b, $14
.asm_4c88
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_4c93
	dec b
	jr nz, .asm_4c88
.asm_4c93
	call .asm_4cb4
	call .asm_4cb4
	push hl
	ld a, $08
	call PlaySFX
	lb bc, 3, 5
	ld a, e
	call WriteTwoDigitNumberInTxSymbolFormat
	lb bc, 18, 7
	ld a, e
	call WriteTwoDigitNumberInTxSymbolFormat
	pop hl
	pop de
	dec e
	dec d
	jr nz, .asm_4c85
	ret

.asm_4cb4
	ld b, [hl]
	inc hl
	ld c, [hl]
	inc hl
	ld a, $ac
	jp WriteByteToBGMap0

.data_4cbd
	db $05, $06, $0e, $05
	db $06, $06, $0d, $05
	db $05, $07, $0e, $04
	db $06, $07, $0d, $04
	db $05, $08, $0e, $03
	db $06, $08, $0d, $03
; 0x4cd5

Func_4cd5: ; 4cd5 (1:4cd5)
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	cp DUELIST_TYPE_PLAYER
	jr z, .player_choose_arena
	cp DUELIST_TYPE_LINK_OPP
	jr z, .exchange_duelvars
	push af
	push hl
	call Func_2bc3
	pop hl
	pop af
	ld [hl], a
	or a
	ret

.exchange_duelvars
	ldtx hl, TransmitingDataText
	call DrawWideTextBox_PrintText
	call ExchangeRNG
	ld hl, wPlayerDuelVariables
	ld de, wOpponentDuelVariables
	ld c, (wOpponentDuelVariables - wPlayerDuelVariables) / 2
	call SerialExchangeBytes
	jr c, .error
	ld c, (wOpponentDuelVariables - wPlayerDuelVariables) / 2
	call SerialExchangeBytes
	jr c, .error
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	ld [hl], DUELIST_TYPE_LINK_OPP
	or a
	ret
.error
	jp DuelTransmissionError

.player_choose_arena
	call EmptyScreen
	ld a, BOXMSG_ARENA_POKEMON
	call DrawDuelBoxMessage
	ldtx hl, ChooseBasicPkmnToPlaceInArenaText
	call DrawWideTextBox_WaitForInput
	ld a, $1
	call DoPracticeDuelAction
.asm_4d28
	xor a
	ldtx hl, PleaseChooseAnActivePokemonText
	call Func_5502
	jr c, .asm_4d28
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, $2
	call DoPracticeDuelAction
	jr c, .asm_4d28
	ldh a, [hTempCardIndex_ff98]
	call PutHandPokemonCardInPlayArea
	ldh a, [hTempCardIndex_ff98]
	ldtx hl, PlacedInTheArenaText
	call DisplayCardDetailScreen
	jr .choose_bench

.choose_bench
	call EmptyScreen
	ld a, BOXMSG_BENCH_POKEMON
	call DrawDuelBoxMessage
	ldtx hl, ChooseUpTo5BasicPkmnToPlaceOnBenchText
	call PrintScrollableText_NoTextBoxLabel
	ld a, $3
	call DoPracticeDuelAction
.bench_loop
	ld a, $1
	ldtx hl, ChooseYourBenchPokemonText
	call Func_5502
	jr c, .asm_4d8e
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	cp MAX_PLAY_AREA_POKEMON
	jr nc, .no_space
	ldh a, [hTempCardIndex_ff98]
	call PutHandPokemonCardInPlayArea
	ldh a, [hTempCardIndex_ff98]
	ldtx hl, PlacedOnTheBenchText
	call DisplayCardDetailScreen
	ld a, $5
	call DoPracticeDuelAction
	jr .bench_loop

.no_space
	ldtx hl, NoSpaceOnTheBenchText
	call DrawWideTextBox_WaitForInput
	jr .bench_loop

.asm_4d8e
	ld a, $4
	call DoPracticeDuelAction
	jr c, .bench_loop
	or a
	ret
; 0x4d97

; the turn duelist shuffles the deck unless it's a practice duel, then draws 7 cards
; returns $00 in a and carry if no basic Pokemon cards are drawn, and $01 in a otherwise
ShuffleDeckAndDrawSevenCards: ; 4d97 (1:4d97)
	call InitializeDuelVariables
	ld a, [wDuelType]
	cp DUELTYPE_PRACTICE
	jr z, .deck_ready
	call ShuffleDeck
	call ShuffleDeck
.deck_ready
	ld b, 7
.draw_loop
	call DrawCardFromDeck
	call AddCardToHand
	dec b
	jr nz, .draw_loop
	ld a, DUELVARS_HAND
	call GetTurnDuelistVariable
	ld b, $00
	ld c, 7
.cards_loop
	ld a, [hli]
	push hl
	push bc
	call LoadCardDataToBuffer1_FromDeckIndex
	call .check_basic_pokemon
	pop bc
	pop hl
	or b
	ld b, a
	dec c
	jr nz, .cards_loop
	ld a, b
	or a
	ret nz
	xor a
	scf
	ret

.asm_4dd1
	ld a, [wLoadedCard1ID]
	cp MYSTERIOUS_FOSSIL
	jr z, .basic
	cp CLEFAIRY_DOLL
	jr z, .basic
.check_basic_pokemon
	ld a, [wLoadedCard1Type]
	cp TYPE_ENERGY
	jr nc, .energy_trainer_nonbasic
	ld a, [wLoadedCard1Stage]
	or a
	jr nz, .energy_trainer_nonbasic

; basic
	ld a, $01
	ret
.energy_trainer_nonbasic
	xor a
	scf
	ret
.basic
	ld a, $01
	or a
	ret
; 0x4df3

DisplayNoBasicPokemonInHandScreenAndText: ; 4df3 (1:4df3)
	ldtx hl, ThereAreNoBasicPokemonInHand
	call DrawWideTextBox_WaitForInput
	call DisplayNoBasicPokemonInHandScreen
;	fallthrough

; prints ReturnCardsToDeckAndDrawAgainText in a textbox and calls ExchangeRNG
PrintReturnCardsToDeckDrawAgain: ; 4dfc (1:4dfc)
	ldtx hl, ReturnCardsToDeckAndDrawAgainText
	call DrawWideTextBox_WaitForInput
	call ExchangeRNG
	ret
; 0x4e06

; display a bare list of seven hand cards of the turn duelist, and the duelist's name above
; used to let the player know that there are no basic Pokemon in the hand and need to redraw
DisplayNoBasicPokemonInHandScreen: ; 4e06 (1:4e06)
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	lb de, 0, 0
	lb bc, 20, 18
	call DrawRegularTextBox
	call CreateHandCardList
	call CountCardsInDuelTempList
	ld hl, NoBasicPokemonCardListParameters
	lb de, 0, 0
	call PrintCardListItems
	ldtx hl, DuelistHandText
	lb de, 1, 1
	call InitTextPrinting
	call PrintTextNoDelay
	call EnableLCD
	call WaitForWideTextBoxInput
	ret
; 0x4e37

NoBasicPokemonCardListParameters:
	db 1, 3 ; cursor x, cursor y
	db 4 ; item x
	db 14 ; maximum length, in tiles, occupied by the name and level string of each card in the list
	db 7 ; number of items selectable without scrolling
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw $0000 ; function pointer if non-0

Func_4e40: ; 4e40 (1:4e40)
	call CreateHandCardList
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	lb de, 0, 0
	lb bc, 20, 13
	call DrawRegularTextBox
	call CountCardsInDuelTempList ; list length
	ld hl, CardListParameters ; other list params
	lb de, 0, 0 ; initial page scroll offset, initial item (in the visible page)
	call PrintCardListItems
	ldtx hl, DuelistHandText
	lb de, 1, 1
	call InitTextPrinting
	call PrintTextNoDelay
	call EnableLCD
	ret
; 0x4e6e

Func_4e6e: ; 4e6e (1:4e6e)
	ld b, $51
	ld c, $56
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .asm_4e7c
	ld b, $52
	ld c, $57
.asm_4e7c
	ld hl, $63
	ld de, $67
	jr Func_4e98

Func_4e84: ; 4e84 (1:4e84)
	ld b, $53
	ld c, $55
	ld hl, $65
	ld de, $66
	ld a, [wDuelType]
	cp DUELTYPE_PRACTICE
	jr nz, Func_4e98
	ld hl, $64
;	fallthrough

Func_4e98: ; 4e98 (1:4e98)
	push bc
	push de
	push hl
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call DrawDuelistPortraitsAndNames
	call LoadDuelDrawCardsScreenTiles
	ld a, SHUFFLE_DECK
	ld [wDuelDisplayedScreen], a
	pop hl
	call DrawWideTextBox_PrintText
	call EnableLCD
	ld a, [wDuelType]
	cp DUELTYPE_PRACTICE
	jr nz, .asm_4ebf
	call WaitForWideTextBoxInput
	jr .asm_4ee0
.asm_4ebf
	call Func_3b21
	ld hl, sp+$03
	ld a, [hl]
	call Func_3b6a
	ld a, [hl]
	call Func_3b6a
	ld a, [hl]
	call Func_3b6a
.asm_4ed0
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_4edd
	call Func_3b52
	jr c, .asm_4ed0
.asm_4edd
	call Func_3b31
.asm_4ee0
	xor a
	ld [wNumCardsBeingDrawn], a
	call PrintDeckAndHandIconsAndNumberOfCards
	call Func_3b21
	pop hl
	call DrawWideTextBox_PrintText
.asm_4eee
	ld hl, sp+$00
	ld a, [hl]
	call Func_3b6a
.asm_4ef4
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_4f28
	call Func_3b52
	jr c, .asm_4ef4
	ld hl, wNumCardsBeingDrawn
	inc [hl]
	ld hl, sp+$00
	ld a, [hl]
	cp $55
	jr nz, .asm_4f11
	call PrintDeckAndHandIconsAndNumberOfCards.not_cgb
	jr .asm_4f14
.asm_4f11
	call PrintNumberOfHandAndDeckCards
.asm_4f14
	ld a, [wNumCardsBeingDrawn]
	cp 7
	jr c, .asm_4eee
	ld c, 30
.wait_loop
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_4f28
	dec c
	jr nz, .wait_loop
.asm_4f28
	call Func_3b31
	pop bc
	ret
; 0x4f2d

Func_4f2d: ; 4f2d (1:4f2d)
	ld a, [wDuelDisplayedScreen]
	cp SHUFFLE_DECK
	jr z, .asm_4f3d
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call DrawDuelistPortraitsAndNames
.asm_4f3d
	ld a, SHUFFLE_DECK
	ld [wDuelDisplayedScreen], a
	ld a, DUELVARS_NUMBER_OF_CARDS_NOT_IN_DECK
	call GetTurnDuelistVariable
	ld a, DECK_SIZE
	sub [hl]
	cp 2
	jr c, .one_card_in_deck
	ldtx hl, ShufflesTheDeckText
	call DrawWideTextBox_PrintText
	call EnableLCD
	call Func_3b21
	ld e, $51
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .asm_4f64
	ld e, $52
.asm_4f64
	ld a, e
	call Func_3b6a
	ld a, e
	call Func_3b6a
	ld a, e
	call Func_3b6a
.asm_4f70
	call DoFrame
	call CheckSkipDelayAllowed
	jr c, .asm_4f7d
	call Func_3b52
	jr c, .asm_4f70
.asm_4f7d
	call Func_3b31
	ld a, $01
	ret
.one_card_in_deck
	ld l, a
	ld h, $00
	call LoadTxRam3
	ldtx hl, DeckHasXCardsText
	call DrawWideTextBox_PrintText
	call EnableLCD
	ld a, $3c
.asm_4f94
	call DoFrame
	dec a
	jr nz, .asm_4f94
	ld a, $01
	ret
; 0x4f9d

; draw the main scene during a duel, except the contents of the bottom text box,
; which depend on the type of duelist holding the turn.
; includes the background, both arena Pokemon, and both HUDs.
DrawDuelMainScene: ; 4f9d (1:4f9d)
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	cp DUELIST_TYPE_PLAYER
	jr z, .draw
	ldh a, [hWhoseTurn]
	push af
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	call .draw
	pop af
	ldh [hWhoseTurn], a
	ret
.draw
; first, load the graphics and draw the background scene
	ld a, [wDuelDisplayedScreen]
	cp DUEL_MAIN_SCENE
	ret z
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadSymbolsFont
	ld a, DUEL_MAIN_SCENE
	ld [wDuelDisplayedScreen], a
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	ld de, v0Tiles1 + $50 tiles
	call LoadPlayAreaCardGfx
	call SetBGP7OrSGB2ToCardPalette
	call SwapTurn
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	ld de, v0Tiles1 + $20 tiles
	call LoadPlayAreaCardGfx
	call SetBGP6OrSGB3ToCardPalette
	call FlushAllPalettesOrSendPal23Packet
	call SwapTurn
; next, draw the Pokemon in the arena
;.place_player_arena_pkmn
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	jr z, .place_opponent_arena_pkmn
	ld a, $d0 ; v0Tiles1 + $50 tiles
	lb hl, 6, 1
	lb de, 0, 5
	lb bc, 8, 6
	call FillRectangle
	call ApplyBGP7OrSGB2ToCardImage
.place_opponent_arena_pkmn
	call SwapTurn
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	jr z, .place_other_elements
	ld a, $a0 ; v0Tiles1 + $20 tiles
	lb hl, 6, 1
	lb de, 12, 1
	lb bc, 8, 6
	call FillRectangle
	call ApplyBGP6OrSGB3ToCardImage
.place_other_elements
	call SwapTurn
	ld hl, DuelEAndHPTileData
	call WriteDataBlocksToBGMap0
	call DrawDuelHorizontalSeparator
	call DrawDuelHUDs
	call DrawWideTextBox
	call EnableLCD
	ret
; 0x503a

; draws the main elements of the main duel interface, including HUDs, HPs, card names
; and color symbols, attached cards, and other information, of both duelists.
DrawDuelHUDs: ; 503a (1:503a)
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	cp DUELIST_TYPE_PLAYER
	jr z, .draw_hud
	ldh a, [hWhoseTurn]
	push af
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	call .draw_hud
	pop af
	ldh [hWhoseTurn], a
	ret
.draw_hud
	lb de, 1, 11 ; coordinates for player's arena card name and info icons
	lb bc, 11, 8 ; coordinates for player's attached energies and HP bar
	call DrawDuelHUD
	lb bc, 8, 5
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	call CheckPrintCnfSlpPrz
	inc c
	call CheckPrintPoisoned
	inc c
	call CheckPrintDoublePoisoned
	call SwapTurn
	lb de, 7, 0 ; coordinates for opponent's arena card name and info icons
	lb bc, 3, 1 ; coordinates for opponent's attached energies and HP bar
	call GetNonTurnDuelistVariable
	call DrawDuelHUD
	lb bc, 11, 6
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	call CheckPrintCnfSlpPrz
	dec c
	call CheckPrintPoisoned
	dec c
	call CheckPrintDoublePoisoned
	call SwapTurn
	ret
; 0x5093

DrawDuelHUD: ; 5093 (1:5093)
	ld hl, wHUDEnergyAndHPBarsX
	ld [hl], b
	inc hl
	ld [hl], c ; wHUDEnergyAndHPBarsY
	push de ; push coordinates for the arena card name
	ld d, 1 ; opponent's info icons start in the second tile to the right
	ld a, e
	or a
	jr z, .go
	ld d, 15 ; player's info icons start in the 15th tile to the right
.go
	push de
	pop bc

	; print the Pokemon icon along with the no. of play area Pokemon
	ld a, SYM_POKEMON
	call WriteByteToBGMap0
	inc b
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	add SYM_0 - 1
	call WriteByteToBGMap0
	inc b

	; print the Prize icon along with the no. of prizes yet to draw
	ld a, SYM_PRIZE
	call WriteByteToBGMap0
	inc b
	call CountPrizes
	add SYM_0
	call WriteByteToBGMap0

	; print the arena Pokemon card name and level text
	pop de
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	ret z
	call LoadCardDataToBuffer1_FromDeckIndex
	push de
	ld a, 32
	call CopyCardNameAndLevel
	ld [hl], TX_END

	; print the arena Pokemon card color symbol just before the name
	pop de
	ld a, e
	or a
	jr nz, .print_color_icon
	ld hl, wDefaultText
	call GetTextSizeInTiles
	add SCREEN_WIDTH
	ld d, a
.print_color_icon
	call InitTextPrinting
	ld hl, wDefaultText
	call ProcessText
	push de
	pop bc
	call GetArenaCardColor
	inc a ; TX_SYMBOL color tiles start at 1
	dec b ; place the color symbol one tile to the left of the start of the card's name
	call JPWriteByteToBGMap0

	; print attached energies
	ld hl, wHUDEnergyAndHPBarsX
	ld b, [hl]
	inc hl
	ld c, [hl] ; wHUDEnergyAndHPBarsY
	lb de, 9, PLAY_AREA_ARENA
	call PrintPlayAreaCardAttachedEnergies

	; print HP bar
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, [wLoadedCard1HP]
	ld d, a ; max HP
	ld a, DUELVARS_ARENA_CARD_HP
	call GetTurnDuelistVariable
	ld e, a ; cur HP
	call DrawHPBar
	ld hl, wHUDEnergyAndHPBarsX
	ld b, [hl]
	inc hl
	ld c, [hl] ; wHUDEnergyAndHPBarsY
	inc c ; [wHUDEnergyAndHPBarsY] + 1
	call BCCoordToBGMap0Address
	push de
	ld hl, wDefaultText
	ld b, HP_BAR_LENGTH / 2 ; first row of the HP bar
	call SafeCopyDataHLtoDE
	pop de
	ld hl, BG_MAP_WIDTH
	add hl, de
	ld e, l
	ld d, h
	ld hl, wDefaultText + HP_BAR_LENGTH / 2
	ld b, HP_BAR_LENGTH / 2 ; second row of the HP bar
	call SafeCopyDataHLtoDE

	; print number of attached Pluspower and Defender with respective icon, if any
	ld hl, wHUDEnergyAndHPBarsX
	ld a, [hli]
	add 6
	ld b, a
	ld c, [hl] ; wHUDEnergyAndHPBarsY
	inc c
	ld a, DUELVARS_ARENA_CARD_ATTACHED_PLUSPOWER
	call GetTurnDuelistVariable
	or a
	jr z, .check_defender
	ld a, SYM_PLUSPOWER
	call WriteByteToBGMap0
	inc b
	ld a, [hl] ; number of attached Pluspower
	add SYM_0
	call WriteByteToBGMap0
	dec b
.check_defender
	ld a, DUELVARS_ARENA_CARD_ATTACHED_DEFENDER
	call GetTurnDuelistVariable
	or a
	jr z, .done
	inc c
	ld a, SYM_DEFENDER
	call WriteByteToBGMap0
	inc b
	ld a, [hl] ; number of attached Defender
	add SYM_0
	call WriteByteToBGMap0
.done
	ret
; 0x516f

; draws an horizonal line that separates the arena side of each duelist
; also colorizes the line on CGB
DrawDuelHorizontalSeparator: ; 516f (1:516f)
	ld hl, DuelHorizontalSeparatorTileData
	call WriteDataBlocksToBGMap0
	ld a, [wConsole]
	cp CONSOLE_CGB
	ret nz
	call BankswitchVRAM1
	ld hl, DuelHorizontalSeparatorCGBPalData
	call WriteDataBlocksToBGMap0
	call BankswitchVRAM0
	ret
; 0x5188

DuelEAndHPTileData: ; 5188 (1:5188)
; x, y, tiles[], 0
	db 1, 1, SYM_E,  0
	db 1, 2, SYM_HP, 0
	db 9, 8, SYM_E,  0
	db 9, 9, SYM_HP, 0
	db $ff
; 0x5199

DuelHorizontalSeparatorTileData: ; 5199 (1:5199)
; x, y, tiles[], 0
	db 0, 4, $37, $37, $37, $37, $37, $37, $37, $37, $37, $31, $32, 0
	db 9, 5, $33, $34, 0
	db 9, 6, $33, $34, 0
	db 9, 7, $35, $36, $37, $37, $37, $37, $37, $37, $37, $37, $37, 0
	db $ff
; 0x51c0

DuelHorizontalSeparatorCGBPalData: ; 51c0 (1:51c0)
; x, y, pals[], 0
	db 0, 4, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, 0
	db 9, 5, $02, $02, 0
	db 9, 6, $02, $02, 0
	db 9, 7, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, 0
	db $ff
; 0x51e7

; if this is a practice duel, execute the practice duel action at wPracticeDuelAction
DoPracticeDuelAction: ; 51e7 (1:51e7)
	ld [wPracticeDuelAction], a
	ld a, [wIsPracticeDuel]
	or a
	ret z
	ld a, [wPracticeDuelAction]
	ld hl, PracticeDuelActionTable
	jp JumpToFunctionInTable
; 0x51f8

PracticeDuelActionTable: ; 51f8 (1:51f8)
	dw $0000
	dw Func_520e
	dw Func_521a
	dw Func_522a
	dw Func_5236
	dw Func_5245
	dw Func_5256
	dw Func_5278
	dw Func_5284
	dw Func_529b
	dw Func_52b0
; 0x520e

Func_520e: ; 520e (1:520e)
	call Func_4e40
	call EnableLCD
	ldtx hl, Text01a4
	jp Func_52bc
; 0x521a

Func_521a: ; 521a (1:521a)
	ld a, [wLoadedCard1ID]
	cp GOLDEEN
	ret z
	ldtx hl, Text01a5
	ldtx de, DrMasonText
	scf
	jp Func_52bc
; 0x522a

Func_522a: ; 522a (1:522a)
	call Func_4e40
	call EnableLCD
	ldtx hl, Text01a6
	jp Func_52bc
; 0x5236

Func_5236: ; 5236 (1:5236)
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	cp 2
	ret z
	ldtx hl, Text01a7
	scf
	jp Func_52bc
; 0x5245

Func_5245: ; 5245 (1:5245)
	call Func_4e40
	call EnableLCD
	ld a, $ff
	ld [wcc00], a
	ldtx hl, Text01a8
	jp Func_52bc
; 0x5256

Func_5256: ; 5256 (1:5256)
	call $5351
	call EnableLCD
	ld a, [wDuelTurns]
	ld hl, wcc00
	cp [hl]
	ld [hl], a
	ld a, $00
	jp nz, $5382
	ldtx de, DrMasonText
	ldtx hl, Text01d9
	call PrintScrollableText_WithTextBoxLabel_NoWait
	call YesOrNoMenu
	jp $5382
; 0x5278

Func_5278: ; 5278 (1:5278)
	ld a, [wDuelTurns]
	srl a
	ld hl, $541f
	call JumpToFunctionInTable
	ret nc
;	fallthrough

Func_5284: ; 5284 (1:5284)
	ldtx hl, Text01da
	call Func_52bc
	ld a, $02
	call BankswitchSRAM
	ld de, sCurrentDuel
	call $66ff
	xor a
	call BankswitchSRAM
	scf
	ret
; 0x529b

Func_529b: ; 529b (1:529b)
	ld a, [wDuelTurns]
	cp 7
	jr z, .asm_52a4
	or a
	ret
.asm_52a4
	call $5351
	call EnableLCD
	ld hl, $5346
	jp $5396
; 0x52b0

Func_52b0: ; 52b0 (1:52b0)
	ldh a, [hTempPlayAreaLocation_ff9d]
	cp PLAY_AREA_BENCH_1
	ret z
	call HasAlivePokemonOnBench
	ldtx hl, Text01d7
	scf
;	fallthrough

Func_52bc: ; 52bc (1:52bc)
	push af
	ldtx de, DrMasonText
	call PrintScrollableText_WithTextBoxLabel
	pop af
	ret
; 0x52c5

	INCROM $52c5,  $54c8

; display BOXMSG_PLAYERS_TURN or BOXMSG_OPPONENTS_TURN and print
; DuelistsTurnText in a textbox. also call ExchangeRNG.
DisplayDuelistTurnScreen: ; 54c8 (1:54c8)
	call EmptyScreen
	ld c, BOXMSG_PLAYERS_TURN
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .got_turn
	inc c ; BOXMSG_OPPONENTS_TURN
.got_turn
	ld a, c
	call DrawDuelBoxMessage
	ldtx hl, DuelistsTurnText
	call DrawWideTextBox_WaitForInput
	call ExchangeRNG
	ret
; 0x54e2

Unknown_54e2: ; 54e2 (1:54e2)
; ???
	db $00, $0c, $06, $0f, $00, $00, $00
; 0x54e9

DuelMenuData: ; 54e9 (1:54e9)
	; x, y, text id
	textitem 3,  14, HandText
	textitem 9,  14, CheckText
	textitem 15, 14, RetreatText
	textitem 3,  16, AttackText
	textitem 9,  16, PKMNPowerText
	textitem 15, 16, DoneText
	db $ff
; 0x5502

Func_5502: ; 5502 (1:5502)
	ld [wcbfd], a
	push hl
	call CreateHandCardList
	call InitAndDrawCardListScreenLayout
	pop hl
	call SetCardListInfoBoxText
	ld a, PLAY_CHECK
	ld [wCardListItemSelectionMenuType], a
.asm_5515
	call Func_55f0
	jr nc, .asm_5523
	ld a, [wcbfd]
	or a
	jr z, .asm_5515
	scf
	jr .asm_5538
.asm_5523
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	call Func_4dd1
	jr nc, .asm_5538
	ldtx hl, YouCannotSelectThisCardText
	call DrawWideTextBox_WaitForInput
	call DrawCardListScreenLayout
	jr .asm_5515
.asm_5538
	push af
	ld a, [wSortCardListByID]
	or a
	call nz, SortHandCardsByID
	pop af
	ret
; 0x5542

Func_5542: ; 5542 (1:5542)
	call CreateDiscardPileCardList
	ret c
	call InitAndDrawCardListScreenLayout
	call SetDiscardPileScreenTexts
	call Func_55f0
	ret
; 0x5550

; draw the turn holder's discard pile screen
OpenDiscardPileScreen: ; 5550 (1:5550)
	call CreateDiscardPileCardList
	jr c, .discard_pile_empty
	call InitAndDrawCardListScreenLayout
	call SetDiscardPileScreenTexts
	ld a, START + A_BUTTON
	ld [wWatchedButtons_cbd6], a
	call Func_55f0
	or a
	ret
.discard_pile_empty
	ldtx hl, TheDiscardPileHasNoCardsText
	call DrawWideTextBox_WaitForInput
	scf
	ret
; 0x556d

; set wCardListHeaderText and SetCardListInfoBoxText to the text
; that correspond to the Discard Pile screen
SetDiscardPileScreenTexts: ; 556d (1:556d)
	ldtx de, YourDiscardPileText
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .got_header_text
	ldtx de, OpponentsDiscardPileText
.got_header_text
	ldtx hl, ChooseTheCardYouWishToExamineText
	call SetCardListHeaderText
	ret
; 0x5580

SetCardListHeaderText: ; 5580 (1:5580)
	ld a, e
	ld [wCardListHeaderText], a
	ld a, d
	ld [wCardListHeaderText + 1], a
;	fallthrough

SetCardListInfoBoxText: ; 5588 (1:5588)
	ld a, l
	ld [wCardListInfoBoxText], a
	ld a, h
	ld [wCardListInfoBoxText + 1], a
	ret
; 0x5591

Func_5591: ; 5591 (1:5591)
	call InitAndDrawCardListScreenLayout
	ld a, SELECT_CHECK
	ld [wCardListItemSelectionMenuType], a
	ret
; 0x559a

; draw the layout of the screen that displays the player's Hand card list or a
; Discard Pile card list, including a bottom-right image of the current card.
; since this loads the text for the Hand card list screen, SetDiscardPileScreenTexts
; is called after this if the screen corresponds to a Discard Pile list.
InitAndDrawCardListScreenLayout: ; 559a (1:559a)
	xor a
	ld hl, wSelectedDuelSubMenuItem
	ld [hli], a
	ld [hl], a
	ld [wSortCardListByID], a
	ld hl, wcbd8
	ld [hli], a
	ld [hl], a
	ld [wCardListItemSelectionMenuType], a
	ld a, START
	ld [wWatchedButtons_cbd6], a
	ld hl, wCardListInfoBoxText
	ldtx [hl], PleaseSelectHandText, & $ff
	inc hl
	ldtx [hl], PleaseSelectHandText, >> 8
	inc hl ; wCardListHeaderText
	ldtx [hl], DuelistHandText, & $ff
	inc hl
	ldtx [hl], DuelistHandText, >> 8
; fallthrough

; same as InitAndDrawCardListScreenLayout, except that variables like wSelectedDuelSubMenuItem,
; wWatchedButtons_cbd6, wCardListInfoBoxText, wCardListHeaderText, etc already set by caller.
DrawCardListScreenLayout:
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadSymbolsFont
	call LoadDuelCardSymbolTiles
	; draw the surrounding box
	lb de, 0, 0
	lb bc, 20, 13
	call DrawRegularTextBox
	; draw the image of the selected card
	ld a, $a0
	lb hl, 6, 1
	lb de, 12, 12
	lb bc, 8, 6
	call FillRectangle
	call ApplyBGP6OrSGB3ToCardImage
	call Func_5744
	ld a, [wDuelTempList]
	cp $ff
	scf
	ret z
	or a
	ret
; 0x55f0

Func_55f0: ; 55f0 (1:55f0)
	call DrawNarrowTextBox
	call PrintCardListHeaderAndInfoBoxTexts
.asm_55f6
	call CountCardsInDuelTempList ; list length
	ld hl, wSelectedDuelSubMenuItem
	ld e, [hl] ; initial item (in the visible page)
	inc hl
	ld d, [hl] ; initial page scroll offset
	ld hl, CardListParameters ; other list params
	call PrintCardListItems
	call LoadSelectedCardGfx
	call EnableLCD
.wait_button
	call DoFrame
	call Func_5690
	call HandleCardListInput
	jr nc, .wait_button
	ld hl, wSelectedDuelSubMenuItem
	ld [hl], e
	inc hl
	ld [hl], d
	ldh a, [hKeysPressed]
	ld b, a
	bit SELECT_F, b
	jr nz, .select_pressed
	bit B_BUTTON_F, b
	jr nz, .b_pressed
	ld a, [wWatchedButtons_cbd6]
	and b
	jr nz, .relevant_press
	ldh a, [hCurMenuItem]
	call GetCardInDuelTempList_OnlyDeckIndex
	call Func_56c2
	jr c, Func_55f0
	ldh a, [hTempCardIndex_ff98]
	or a
	ret
.select_pressed
	ld a, [wSortCardListByID]
	or a
	jr nz, .wait_button
	call SortCardsInDuelTempListByID
	xor a
	ld hl, wSelectedDuelSubMenuItem
	ld [hli], a
	ld [hl], a
	ld a, 1
	ld [wSortCardListByID], a
	call EraseCursor
	jr .asm_55f6
.relevant_press
	ldh a, [hCurMenuItem]
	call GetCardInDuelTempList
	call LoadCardDataToBuffer1_FromDeckIndex
	call Func_5762
	ldh a, [hDPadHeld]
	bit D_UP_F, a
	jr nz, .asm_566f
	bit D_DOWN_F, a
	jr nz, .asm_5677
	call DrawCardListScreenLayout
	jp Func_55f0
.asm_566f
	ldh a, [hCurMenuItem]
	or a
	jr z, .relevant_press
	dec a
	jr .asm_5681
.asm_5677
	call CountCardsInDuelTempList
	ld b, a
	ldh a, [hCurMenuItem]
	inc a
	cp b
	jr nc, .relevant_press
.asm_5681
	ldh [hCurMenuItem], a
	ld hl, wSelectedDuelSubMenuItem
	ld [hl], $00
	inc hl
	ld [hl], a
	jr .relevant_press
.b_pressed
	ldh a, [hCurMenuItem]
	scf
	ret
; 0x5690

Func_5690: ; 5690 (1:5690)
	ldh a, [hDPadHeld]
	and D_PAD
	ret z
	ld a, $01
	ldh [hffb0], a
	call PrintCardListHeaderAndInfoBoxTexts
	xor a
	ldh [hffb0], a
	ret
; 0x56a0

; prints the text ID at wCardListHeaderText at 1,1
; and the text ID at wCardListInfoBoxText at 1,14
PrintCardListHeaderAndInfoBoxTexts: ; 56a0 (1:56a0)
	lb de, 1, 14
	call AdjustCoordinatesForBGScroll
	call InitTextPrinting
	ld hl, wCardListInfoBoxText
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call PrintTextNoDelay
	ld hl, wCardListHeaderText
	ld a, [hli]
	ld h, [hl]
	ld l, a
	lb de, 1, 1
	call InitTextPrinting
	call PrintTextNoDelay
	ret
; 0x56c2

Func_56c2: ; 56c2 (1:56c2)
	ld a, [wCardListItemSelectionMenuType]
	or a
	ret z
	ldtx hl, SelectCheckText
	ld a, [wCardListItemSelectionMenuType]
	cp PLAY_CHECK
	jr nz, .got_text
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	ldtx hl, PlayCheck2Text ; identical to PlayCheck1Text
	ld a, [wLoadedCard1Type]
	cp TYPE_TRAINER
	jr nz, .got_text
	ldtx hl, PlayCheck1Text
.got_text
	call DrawNarrowTextBox_PrintTextNoDelay
	ld hl, ItemSelectionMenuParamenters
	xor a
	call InitializeMenuParameters
.wait_a_or_b
	call DoFrame
	call HandleMenuInput
	jr nc, .wait_a_or_b
	cp -1
	jr z, .b_pressed
	; a pressed
	or a
	ret z
	ldh a, [hTempCardIndex_ff98]
	call LoadCardDataToBuffer1_FromDeckIndex
	call Func_5773
	call DrawCardListScreenLayout
.b_pressed
	scf
	ret
; 0x5708

ItemSelectionMenuParamenters ; 5708 (1:5708)
	db 1, 14 ; corsor x, cursor y
	db 2 ; y displacement between items
	db 2 ; number of items
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw $0000 ; function pointer if non-0
; 0x5710

CardListParameters: ; 5710 (1:5710)
	db 1, 3 ; cursor x, cursor y
	db 4 ; item x
	db 14 ; maximum length, in tiles, occupied by the name and level string of each card in the list
	db 5 ; number of items selectable without scrolling
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw CardListFunction ; function pointer if non-0
; 0x5719

; return carry if any of the buttons is pressed, and load the graphics
; of the card pointed to by the cursor whenever a d-pad key is released.
; also return $ff unto hCurMenuItem if B is pressed.
CardListFunction: ; 5719 (1:5719)
	ldh a, [hKeysPressed]
	bit B_BUTTON_F, a
	jr nz, .exit
	and A_BUTTON | SELECT | START
	jr nz, .action_button
	ldh a, [hKeysReleased]
	and D_PAD
	jr nz, .reload_card_image ; jump if the D_PAD key was released this frame
	ret
.exit
	ld a, $ff
	ldh [hCurMenuItem], a
.action_button
	scf
	ret
.reload_card_image
	call LoadSelectedCardGfx
	or a
	ret
; 0x5735

Func_5735: ; 5735 (1:5735)
	ld hl, wcbd8
	ld de, Func_574a
	ld [hl], e
	inc hl
	ld [hl], d
	ld a, 1
	ld [wSortCardListByID], a
	ret
; 0x5744

Func_5744: ; 5744 (1:5744)
	ld hl, wcbd8
	jp CallIndirect
; 0x574a

Func_574a: ; 574a (1:574a)
	lb bc, 1, 2
	ld hl, wDuelTempList + 10
.next
	ld a, [hli]
	cp $ff
	jr z, .done
	or a ; SYM_SPACE
	jr z, .space
	add SYM_0
.space
	call WriteByteToBGMap0
	; move two lines down
	inc c
	inc c
	jr .next
.done
	ret
; 0x5762

Func_5762: ; 5762 (1:5762)
	ld a, B_BUTTON | D_UP | D_DOWN
	ld [wExitButtons_cbd7], a
	xor a
	jr Func_5779

Func_576a: ; 576a (1:576a)
	ld a, B_BUTTON
	ld [wExitButtons_cbd7], a
	ld a, $01
	jr Func_5779

Func_5773: ; 5773 (1:5773)
	ld a, B_BUTTON
	ld [wExitButtons_cbd7], a
	xor a
;	fallthrough

Func_5779: ; 5779 (1:5779)
	ld [wcbd1], a
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call Func_3b31
	call LoadDuelCardSymbolTiles
	ld de, v0Tiles1 + $20 tiles
	call LoadLoaded1CardGfx
	call SetOBP1OrSGB3ToCardPalette
	call SetBGP6OrSGB3ToCardPalette
	call FlushAllPalettesOrSendPal23Packet
	lb de, $38, $30 ; X Position and Y Position of top-left corner
	call PlaceCardImageOAM
	lb de, 6, 4
	call ApplyBGP6OrSGB3ToCardImage
	xor a
	ld [wCardPageNumber], a
.asm_57a7
	call Func_5898
	jr c, .done
	call EnableLCD
.asm_57af
	call DoFrame
	ldh a, [hDPadHeld]
	ld b, a
	ld a, [wExitButtons_cbd7]
	and b
	jr nz, .done
	ldh a, [hKeysPressed]
	and START | A_BUTTON
	jr nz, .asm_57a7
	ldh a, [hKeysPressed]
	and D_RIGHT | D_LEFT
	jr z, .asm_57af
	call Func_57cd
	jr .asm_57af
.done
	ret
; 0x57cd

Func_57cd: ; 57cd (1:57cd)
	bit D_LEFT_F, a
	jr nz, .left
;.right
	call Func_5898
	call c, Func_589c
	ret
.left
	call Func_5892
	call c, Func_589c
	ret
; 0x57df

	INCROM $57df,  $5892

Func_5892: ; 5892 (1:5892)
	call Func_5911
	jr nc, Func_589c
	ret

Func_5898: ; 5898 (1:5898)
	call Func_58e2
	ret c
;	fallthrough

Func_589c: ; 589c (1:589c)
	ld a, [wCardPageNumber]
	ld hl, CardPagePointerTable
	call JumpToFunctionInTable
	call EnableLCD
	or a
	ret
; 0x58aa

; load the tiles and palette of the card selected in card list screen
LoadSelectedCardGfx: ; 58aa (1:58aa)
	ldh a, [hCurMenuItem]
	call GetCardInDuelTempList
	call LoadCardDataToBuffer1_FromCardID
	ld de, v0Tiles1 + $20 tiles
	call LoadLoaded1CardGfx
	ld de, $c0c ; useless
	call SetBGP6OrSGB3ToCardPalette
	call FlushAllPalettesOrSendPal23Packet
	ret
; 0x58c2

CardPagePointerTable: ; 58c2 (1:58c2)
	dw DrawDuelMainScene
	dw $5b7d ; CARDPAGE_POKEMON_OVERVIEW
	dw $5d1f ; CARDPAGE_POKEMON_MOVE1_1
	dw $5d27 ; CARDPAGE_POKEMON_MOVE1_2
	dw $5d2f ; CARDPAGE_POKEMON_MOVE2_1
	dw $5d37 ; CARDPAGE_POKEMON_MOVE2_2
	dw $5d54 ; CARDPAGE_POKEMON_DESCRIPTION
	dw DrawDuelMainScene
	dw DrawDuelMainScene
	dw $5e28 ; CARDPAGE_ENERGY
	dw $5e28 ; CARDPAGE_ENERGY + 1
	dw DrawDuelMainScene
	dw DrawDuelMainScene
	dw $5e1c ; CARDPAGE_TRAINER_1
	dw $5e22 ; CARDPAGE_TRAINER_2
	dw DrawDuelMainScene
; 0x58e2

Func_58e2: ; 58e2 (1:58e2)
	ld a, [wCardPageNumber]
	or a
	jr nz, .asm_58ff
	ld a, [wLoadedCard1Type]
	ld b, a
	ld a, CARDPAGE_ENERGY
	bit TYPE_ENERGY_F, b
	jr nz, .set_card_page_nc
	ld a, CARDPAGE_TRAINER_1
	bit TYPE_TRAINER_F, b
	jr nz, .set_card_page_nc
	ld a, CARDPAGE_POKEMON_OVERVIEW
.set_card_page_nc
	ld [wCardPageNumber], a
	or a
	ret
.asm_58ff
	ld hl, wCardPageNumber
	inc [hl]
	ld a, [hl]
	call Func_5930
	jr c, .set_card_page_c
	or a
	ret nz
	jr .asm_58ff
.set_card_page_c
	ld [wCardPageNumber], a
	ret
; 0x5911

Func_5911: ; 5911 (1:5911)
	ld hl, wCardPageNumber
	dec [hl]
	ld a, [hl]
	call Func_5930
	jr c, .asm_591f
	or a
	ret nz
	jr Func_5911
.asm_591f
	ld [wCardPageNumber], a
.asm_5922
	call Func_5930
	or a
	jr nz, .asm_592e
	ld hl, wCardPageNumber
	dec [hl]
	jr .asm_5922
.asm_592e
	scf
	ret
; 0x5930

Func_5930: ; 5930 (1:5930)
	ld hl, CardPagePointerTable2
	jp JumpToFunctionInTable
; 0x5936

CardPagePointerTable2: ; 5936 (1:5936)
	dw $5956
	dw $595a ; CARDPAGE_POKEMON_OVERVIEW
	dw $595e ; CARDPAGE_POKEMON_MOVE1_1
	dw $5963 ; CARDPAGE_POKEMON_MOVE1_2
	dw $5968 ; CARDPAGE_POKEMON_MOVE2_1
	dw $596d ; CARDPAGE_POKEMON_MOVE2_2
	dw $595a ; CARDPAGE_POKEMON_DESCRIPTION
	dw $5973
	dw $5977
	dw $597b ; CARDPAGE_ENERGY
	dw $597f ; CARDPAGE_ENERGY + 1
	dw $5984
	dw $5988
	dw $597b ; CARDPAGE_TRAINER_1
	dw $597f ; CARDPAGE_TRAINER_2
	dw $598c
; 0x5956

	INCROM $5956,  $5990

ZeroObjectPositionsAndToggleOAMCopy: ; 5990 (1:5990)
	call ZeroObjectPositions
	ld a, $01
	ld [wVBlankOAMCopyToggle], a
	ret
; 0x5999

; place OAM for a 8x6 image, using object size 8x16 and obj palette 1.
; d, e: X Position and Y Position of the top-left corner.
; starting tile number is $a0 (v0Tiles1 + $20 tiles).
; used to draw the image of a card in the check card screens.
PlaceCardImageOAM: ; 5999 (1:5999)
	call Set_OBJ_8x16
	ld l, $a0
	ld c, 8 ; number of rows
.next_column
	ld b, 3 ; number of columns
	push de
.next_row
	push bc
	ld c, l ; tile number
	ld b, 1 ; attributes (palette)
	call SetOneObjectAttributes
	pop bc
	inc l
	inc l ; next 8x16 tile
	ld a, 16
	add e ; Y Position += 16 (next 8x16 row)
	ld e, a
	dec b
	jr nz, .next_row
	pop de
	ld a, 8
	add d ; X Position += 8 (next 8x16 column)
	ld d, a
	dec c
	jr nz, .next_column
	ld a, $01
	ld [wVBlankOAMCopyToggle], a
	ret
; 0x59c2

; given the deck index of a card in the play area (i.e. -1 indicates empty)
; load the graphics (tiles and palette) of the card to de
LoadPlayAreaCardGfx: ; 59c2 (1:59c2)
	cp -1
	ret z
	push de
	call LoadCardDataToBuffer1_FromDeckIndex
	pop de
;	fallthrough

; load the graphics (tiles and palette) of the card loaded in wLoadedCard1 to de
LoadLoaded1CardGfx: ; 59ca (1:59ca)
	ld hl, wLoadedCard1Gfx
	ld a, [hli]
	ld h, [hl]
	ld l, a
	lb bc, $30, TILE_SIZE
	call LoadCardGfx
	ret
; 0x59d7

SetBGP7OrSGB2ToCardPalette: ; 59d7 (1:59d7)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, .sgb
	ld a, $07 ; CGB BG Palette 7
	call CopyCGBCardPalette
	ret
.sgb
	ld hl, wCardPalette
	ld de, wTempSGBPacket + 1 ; PAL Packet color #0 (PAL23's SGB2)
	ld b, CGB_PAL_SIZE
.copy_pal_loop
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, .copy_pal_loop
	ret
; 0x59f5

SetBGP6OrSGB3ToCardPalette: ; 59f5 (1:59f5)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, SetSGB3ToCardPalette
	ld a, $06 ; CGB BG Palette 6
	call CopyCGBCardPalette
	ret

SetSGB3ToCardPalette: ; 5a04 (1:5a04)
	ld hl, wCardPalette + 2
	ld de, wTempSGBPacket + 9 ; Pal Packet color #4 (PAL23's SGB3)
	ld b, 6
	jr SetBGP7OrSGB2ToCardPalette.copy_pal_loop
; 0x5a0e

SetOBP1OrSGB3ToCardPalette: ; 5a0e (1:5a0e)
	ld a, $e4
	ld [wOBP0], a
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, SetSGB3ToCardPalette
	ld a, $09 ; CGB Object Palette 1
;	fallthrough

CopyCGBCardPalette: ; 5a1e (1:5a1e)
	add a
	add a
	add a ; a *= CGB_PAL_SIZE
	ld e, a
	ld d, $00
	ld hl, wBackgroundPalettesCGB ; wObjectPalettesCGB - 8 palettes
	add hl, de
	ld de, wCardPalette
	ld b, CGB_PAL_SIZE
.copy_pal_loop
	ld a, [de]
	inc de
	ld [hli], a
	dec b
	jr nz, .copy_pal_loop
	ret
; 0x5a34

FlushAllPalettesOrSendPal23Packet: ; 5a34 (1:5a34)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, .sgb
	call FlushAllPalettes
	ret
.sgb
; sgb PAL23, 1 ; sgb_command, length
; rgb 28, 28, 24
; colors 1-7 carried over
	ld a, PAL23 << 3 + 1
	ld hl, wTempSGBPacket
	ld [hli], a
	ld a, $9c
	ld [hli], a
	ld a, $63
	ld [hld], a
	dec hl
	xor a
	ld [wTempSGBPacket + $f], a
	call SendSGB
	ret
; 0x5a56

ApplyBGP6OrSGB3ToCardImage: ; 5a56 (1:5a56)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, .sgb
	ld a, $06 ; CGB BG Palette 6
	call ApplyCardCGBAttributes
	ret
.sgb
	ld a, 3 << 0 + 3 << 2 ; Color Palette Designation
;	fallthrough

SendCardAttrBlkPacket: ; 5a67 (1:5a67)
	call CreateCardAttrBlkPacket
	call SendSGB
	ret
; 0x5a6e

ApplyBGP7OrSGB2ToCardImage: ; 5a6e (1:5a6e)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, .sgb
	ld a, $07 ; CGB BG Palette 7
	call ApplyCardCGBAttributes
	ret
.sgb
	ld a, 2 << 0 + 2 << 2 ; Color Palette Designation
	jr SendCardAttrBlkPacket
; 0x5a81

Func_5a81: ; 5a81 (1:5a81)
	ld a, [wConsole]
	or a ; CONSOLE_DMG
	ret z
	cp CONSOLE_SGB
	jr z, .sgb
	lb de, 0, 5
	call ApplyBGP7OrSGB2ToCardImage
	lb de, 12, 1
	call ApplyBGP6OrSGB3ToCardImage
	ret
.sgb
	ld a, 2 << 0 + 2 << 2 ; Data Set #1: Color Palette Designation
	lb de, 0, 5 ; Data Set #1: X, Y
	call CreateCardAttrBlkPacket
	push hl
	ld a, 2
	ld [wTempSGBPacket + 1], a ; set number of data sets to 2
	ld hl, wTempSGBPacket + 8
	ld a, 3 << 0 + 3 << 2 ; Data Set #2: Color Palette Designation
	lb de, 12, 1 ; Data Set #2: X, Y
	call CreateCardAttrBlkPacket_DataSet
	pop hl
	call SendSGB
	ret
; 0x5ab5

CreateCardAttrBlkPacket: ; 5ab5 (1:5ab5)
; sgb ATTR_BLK, 1 ; sgb_command, length
; db 1 ; number of data sets
	ld hl, wTempSGBPacket
	push hl
	ld [hl], ATTR_BLK << 3 + 1
	inc hl
	ld [hl], 1
	inc hl
	call CreateCardAttrBlkPacket_DataSet
	xor a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	pop hl
	ret
; 0x5ac9

CreateCardAttrBlkPacket_DataSet: ; 5ac9 (1:5ac9)
; Control Code, Color Palette Designation, X1, Y1, X2, Y2
; db ATTR_BLK_CTRL_INSIDE + ATTR_BLK_CTRL_LINE, a, d, e, d+7, e+5 ; data set 1
	ld [hl], ATTR_BLK_CTRL_INSIDE + ATTR_BLK_CTRL_LINE
	inc hl
	ld [hl], a
	inc hl
	ld [hl], d
	inc hl
	ld [hl], e
	inc hl
	ld a, 7
	add d
	ld [hli], a
	ld a, 5
	add e
	ld [hli], a
	ret
; 0x5adb

; given the 8x6 card image with coordinates at de, fill its BGMap attributes with a
ApplyCardCGBAttributes: ; 5adb (1:5adb)
	call BankswitchVRAM1
	lb hl, 0, 0
	lb bc, 8, 6
	call FillRectangle
	call BankswitchVRAM0
	ret
; 0x5aeb

; set the default game palettes for all three systems
; BGP and OBP0 on DMG
; SGB0 and SGB1 on SGB
; BGP0 to BGP5 and OBP1 on CGB
SetDefaultPalettes: ; 5aeb (1:5aeb)
	ld a, [wConsole]
	cp CONSOLE_SGB
	jr z, .sgb
	cp CONSOLE_CGB
	jr z, .cgb
	ld a, $e4
	ld [wOBP0], a
	ld [wBGP], a
	ld a, $01 ; equivalent to FLUSH_ONE_PAL
	ld [wFlushPaletteFlags], a
	ret
.cgb
	ld a, $04
	ld [wTextBoxFrameType], a
	ld de, CGBDefaultPalettes
	ld hl, wBackgroundPalettesCGB
	ld c, 5 palettes
	call .copy_de_to_hl
	ld de, CGBDefaultPalettes
	ld hl, wObjectPalettesCGB
	ld c, CGB_PAL_SIZE
	call .copy_de_to_hl
	call FlushAllPalettes
	ret
.sgb
	ld a, $04
	ld [wTextBoxFrameType], a
	ld a, PAL01 << 3 + 1
	ld hl, wTempSGBPacket
	push hl
	ld [hli], a
	ld de, Pal01Packet_Default
	ld c, $0e
	call .copy_de_to_hl
	ld [hl], c
	pop hl
	call SendSGB
	ret

.copy_de_to_hl
	ld a, [de]
	inc de
	ld [hli], a
	dec c
	jr nz, .copy_de_to_hl
	ret
; 0x5b44

CGBDefaultPalettes: ; 5b44 (1:5b44)
; BGP0 and OBP0
	rgb 28, 28, 24
	rgb 21, 21, 16
	rgb 10, 10, 8
	rgb 0, 0, 0
; BGP1
	rgb 28, 28, 24
	rgb 30, 29, 0
	rgb 30, 3, 0
	rgb 0, 0, 0
; BGP2
	rgb 28, 28, 24
	rgb 0, 18, 0
	rgb 12, 11, 20
	rgb 0, 0, 0
; BGP3
	rgb 28, 28, 24
	rgb 22, 0 ,22
	rgb 27, 7, 3
	rgb 0, 0, 0
; BGP4
	rgb 28, 28, 24
	rgb 26, 10, 0
	rgb 28, 0, 0
	rgb 0, 0, 0

; first and last byte of the packet not contained here (see SetDefaultPalettes.sgb)
Pal01Packet_Default: ; 5b6c (1:5b6c)
; SGB0
	rgb 28, 28, 24
	rgb 21, 21, 16
	rgb 10, 10, 8
	rgb 0, 0, 0
; SGB1
	rgb 26, 10, 0
	rgb 28, 0, 0
	rgb 0, 0, 0

JPWriteByteToBGMap0: ; 5b7a (1:5b7a)
	jp WriteByteToBGMap0
; 0x5b7d

	INCROM $5b7d, $5c33

Func_5c33: ; 5c33 (1:5c33
	INCROM $5c33, $5e5f

; display the card details of the card in wLoadedCard1
; print the text at hl
_DisplayCardDetailScreen: ; 5e5f (1:5e5f)
	push hl
	call DrawLargePictureOfCard
	ld a, 18
	call CopyCardNameAndLevel
	ld [hl], TX_END
	ld hl, 0
	call LoadTxRam2
	pop hl
	call DrawWideTextBox_WaitForInput
	ret
; 0x5e75

; draw a large picture of the card loaded in wLoadedCard1, including its image
; and a header indicating the type of card (TRAINER, ENERGY, PoKéMoN)
DrawLargePictureOfCard: ; 5e75 (1:5e75)
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadSymbolsFont
	call SetDefaultPalettes
	ld a, LARGE_CARD_PICTURE
	ld [wDuelDisplayedScreen], a
	call LoadCardOrDuelMenuBorderTiles
	ld e, HEADER_TRAINER
	ld a, [wLoadedCard1Type]
	cp TYPE_TRAINER
	jr z, .draw
	ld e, HEADER_ENERGY
	and TYPE_ENERGY
	jr nz, .draw
	ld e, HEADER_POKEMON
.draw
	ld a, e
	call LoadCardTypeHeaderTiles
	ld de, v0Tiles1 + $20 tiles
	call LoadLoaded1CardGfx
	call SetBGP6OrSGB3ToCardPalette
	call FlushAllPalettesOrSendPal23Packet
	ld hl, LargeCardTileData
	call WriteDataBlocksToBGMap0
	lb de, 6, 3
	call ApplyBGP6OrSGB3ToCardImage
	ret
; 0x5eb7

LargeCardTileData: ; 5eb7 (1:5eb7)
	db  5,  0, $d0, $d4, $d4, $d4, $d4, $d4, $d4, $d4, $d4, $d1, 0 ; top border
	db  5,  1, $d6, $e0, $e1, $e2, $e3, $e4, $e5, $e6, $e7, $d7, 0 ; header top
	db  5,  2, $d6, $e8, $e9, $ea, $eb, $ec, $ed, $ee, $ef, $d7, 0 ; header bottom
	db  5,  3, $d6, $a0, $a6, $ac, $b2, $b8, $be, $c4, $ca, $d7, 0 ; image
	db  5,  4, $d6, $a1, $a7, $ad, $b3, $b9, $bf, $c5, $cb, $d7, 0 ; image
	db  5,  5, $d6, $a2, $a8, $ae, $b4, $ba, $c0, $c6, $cc, $d7, 0 ; image
	db  5,  6, $d6, $a3, $a9, $af, $b5, $bb, $c1, $c7, $cd, $d7, 0 ; image
	db  5,  7, $d6, $a4, $aa, $b0, $b6, $bc, $c2, $c8, $ce, $d7, 0 ; image
	db  5,  8, $d6, $a5, $ab, $b1, $b7, $bd, $c3, $c9, $cf, $d7, 0 ; image
	db  5,  9, $d6, 0                                              ; empty line 1 (left)
	db 14,  9, $d7, 0                                              ; empty line 1 (right)
	db  5, 10, $d6, 0                                              ; empty line 2 (left)
	db 14, 10, $d7, 0                                              ; empty line 2 (right)
	db  5, 11, $d2, $d5, $d5, $d5, $d5, $d5, $d5, $d5, $d5, $d3, 0 ; bottom border
	db $ff
; 0x5f4a

; print lines of text with no separation between them
SetNoLineSeparation: ; 5f4a (1:5f4a)
	ld a, $01
;	fallthrough

SetLineSeparation: ; 5f4c (1:5f4c)
	ld [wLineSeparation], a
	ret
; 0x5f50

; separate lines of text by an empty line
SetOneLineSeparation: ; 5f50 (1:5f50)
	xor a
	jr SetLineSeparation
; 0x5f53

	INCROM $5f53, $5fd9

; return carry if the turn holder has any Pokemon with non-zero HP on the bench.
; return how many Pokemon with non-zero HP in b.
; does this by calculating how many Pokemon in play area minus one
HasAlivePokemonOnBench: ; 5fd9 (1:5fd9)
	ld a, $01
	jr _HasAlivePokemonInPlayArea

; return carry if the turn holder has any Pokemon with non-zero HP in the play area.
; return how many Pokemon with non-zero HP in b.
HasAlivePokemonInPlayArea: ; 5fdd (1:5fdd)
	xor a
;	fallthrough

_HasAlivePokemonInPlayArea: ; 5fde (1:5fde)
	ld [wExcludeArenaPokemon], a
	ld b, a
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	sub b
	ld c, a
	ld a, DUELVARS_ARENA_CARD_HP
	add b
	call GetTurnDuelistVariable
	ld b, 0
	inc c
	xor a
	ld [wcbd3], a
	ld [wcbd4], a
	jr .next_pkmn
.loop
	ld a, [hli]
	or a
	jr z, .next_pkmn ; jump if this play area Pokemon has 0 HP
	inc b
.next_pkmn
	dec c
	jr nz, .loop
	ld a, b
	or a
	ret nz
	scf
	ret
; 0x6008

OpenPlayAreaScreenForViewing: ; 6008 (1:6008)
	ld a, START + A_BUTTON
	jr DisplayPlayAreaScreen

OpenPlayAreaScreenForSelection: ; 600c (1:600c)
	ld a, START
;	fallthrough

DisplayPlayAreaScreen: ; 600e (1:600e)
	ld [wWatchedButtons_cbd6], a
	ldh a, [hTempCardIndex_ff98]
	push af
	ld a, [wcbd3]
	or a
	jr nz, .skip_ahead
	xor a
	ld [wSelectedDuelSubMenuItem], a
	inc a
	ld [wcbd3], a
.asm_6022
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelCheckPokemonScreenTiles
	call PrintPlayAreaCardList
	call EnableLCD
.skip_ahead
	ld hl, PlayAreaScreenMenuParameters_ActivePokemonIncluded
	ld a, [wExcludeArenaPokemon]
	or a
	jr z, .init_menu_params
	ld hl, PlayAreaScreenMenuParameters_ActivePokemonExcluded
.init_menu_params
	ld a, [wSelectedDuelSubMenuItem]
	call InitializeMenuParameters
	ld a, [wNumPlayAreaItems]
	ld [wNumMenuItems], a
.asm_604c
	call DoFrame
	call Func_60dd
	jr nc, .asm_6061
	cp $02
	jp z, .asm_60ac
	pop af
	ldh [hTempCardIndex_ff98], a
	ld a, [wcbd4] ; useless
	jr OpenPlayAreaScreenForSelection
.asm_6061
	call HandleMenuInput
	jr nc, .asm_604c
	ld a, e
	ld [wSelectedDuelSubMenuItem], a
	ld a, [wExcludeArenaPokemon]
	add e
	ld [wCurPlayAreaSlot], a
	ld a, [wWatchedButtons_cbd6]
	ld b, a
	ldh a, [hKeysPressed]
	and b
	jr z, .asm_6091
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	jr z, .asm_6022
	call GetCardIDFromDeckIndex
	call LoadCardDataToBuffer1_FromCardID
	call Func_576a
	jr .asm_6022
.asm_6091
	ld a, [wExcludeArenaPokemon]
	ld c, a
	ldh a, [hCurMenuItem]
	add c
	ldh [hTempPlayAreaLocation_ff9d], a
	ldh a, [hCurMenuItem]
	cp $ff
	jr z, .asm_60b5
	ldh a, [hTempPlayAreaLocation_ff9d]
	add DUELVARS_ARENA_CARD_HP
	call GetTurnDuelistVariable
	or a
	jr nz, .asm_60ac
	jr .skip_ahead
.asm_60ac
	pop af
	ldh [hTempCardIndex_ff98], a
	ldh a, [hTempPlayAreaLocation_ff9d]
	ldh [hCurMenuItem], a
	or a
	ret
.asm_60b5
	pop af
	ldh [hTempCardIndex_ff98], a
	ldh a, [hTempPlayAreaLocation_ff9d]
	ldh [hCurMenuItem], a
	scf
	ret
; 0x60be

PlayAreaScreenMenuParameters_ActivePokemonIncluded: ; 60be (1:60be)
	db 0, 0 ; cursor x, cursor y
	db 3 ; y displacement between items
	db 6 ; number of items
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw PlayAreaScreenMenuFunction ; function pointer if non-0

PlayAreaScreenMenuParameters_ActivePokemonExcluded: ; 60c6 (1:60c6)
	db 0, 3 ; cursor x, cursor y
	db 3 ; y displacement between items
	db 6 ; number of items
	db SYM_CURSOR_R ; cursor tile number
	db SYM_SPACE ; tile behind cursor
	dw PlayAreaScreenMenuFunction ; function pointer if non-0

PlayAreaScreenMenuFunction: ; 60ce (1:60ce)
	ldh a, [hKeysPressed]
	and A_BUTTON | B_BUTTON | START
	ret z
	bit B_BUTTON_F, a
	jr z, .start_or_a
	ld a, $ff
	ldh [hCurMenuItem], a
.start_or_a
	scf
	ret
; 0x60dd

Func_60dd: ; 60dd (1:60dd)
	ld a, [wcbd4]
	or a
	ret z
	ldh a, [hKeysPressed]
	and SELECT
	ret z
	ld a, [wcbd4]
	cp $02
	jr z, .asm_6121
	xor a
	ld [wCurrentDuelMenuItem], a
.asm_60f2
	call DrawDuelMainScene
	ldtx hl, SelectingBenchPokemonHandExamineBackText
	call DrawWideTextBox_PrintTextNoDelay
	call Func_615c
.asm_60fe
	call DoFrame
	ldh a, [hKeysPressed]
	and A_BUTTON
	jr nz, .a_pressed
	call Func_6137
	call RefreshMenuCursor
	xor a
	call Func_6862
	jr nc, .asm_60fe
	ldh a, [hKeysPressed]
	and SELECT
	jr z, .asm_60f2
.asm_6119
	call HasAlivePokemonOnBench
	ld a, $01
	ld [wcbd4], a
.asm_6121
	scf
	ret
.a_pressed
	ld a, [wCurrentDuelMenuItem]
	cp 2
	jr z, .asm_6119
	or a
	jr z, .asm_6132
	call Func_3096
	jr .asm_60f2
.asm_6132
	call Func_434e
	jr .asm_60f2
; 0x6137

Func_6137: ; 6137 (1:6137)
	ldh a, [hDPadHeld]
	bit 1, a
	ret nz
	and D_RIGHT | D_LEFT
	ret z
	ld b, a
	ld a, [wCurrentDuelMenuItem]
	bit D_LEFT_F, b
	jr z, .asm_6150
	dec a
	bit D_DOWN_F, a
	jr z, .asm_6156
	ld a, 2
	jr .asm_6156
.asm_6150
	inc a
	cp 3
	jr c, .asm_6156
	xor a
.asm_6156
	ld [wCurrentDuelMenuItem], a
	call EraseCursor
;	fallthrough

Func_615c:
	ld a, [wCurrentDuelMenuItem]
	ld d, a
	add a
	add d
	add a
	add 2
	ld d, a
	ld e, 16
	lb bc, SYM_CURSOR_R, SYM_SPACE
	jp SetCursorParametersForTextBox
; 0x616e

Func_616e: ; 616e (1:616e)
	ldh [hTempPlayAreaLocation_ff9d], a
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelCheckPokemonScreenTiles
	xor a
	ld [wExcludeArenaPokemon], a
	call PrintPlayAreaCardList
	call EnableLCD
;	fallthrough

Func_6186:
	ld hl, wCurPlayAreaSlot
	ldh a, [hTempPlayAreaLocation_ff9d]
	ld [hli], a
	ld c, a
	add a
	add c
	ld [hl], a
	call PrintPlayAreaCardInformationAndLocation
	ret
; 0x6194

Func_6194: ; 6194 (1:6194)
	call Func_6186
	ld a, [wCurPlayAreaY]
	ld e, a
	ld d, 0
	call SetCursorParametersForTextBox_Default
	ret
; 0x61a1

Func_61a1: ; 61a1 (1:61a1)
	xor a
	ld [wExcludeArenaPokemon], a
	ld a, [wDuelDisplayedScreen]
	cp PLAY_AREA_CARD_LIST
	ret z
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelCheckPokemonScreenTiles
	ret
; 0x61b8

; for each turn holder's play area Pokemon card, print the name, level,
; face down stage card, color symbol, status symbol (if any), pluspower/defender
; symbols (if any), attached energies (if any), and HP bar.
; also print the play area locations (ACT/BPx indicators) for each of the six slots.
; return the value of wNumPlayAreaItems (as returned from PrintPlayAreaCardList) in a.
PrintPlayAreaCardList_EnableLCD: ; 61b8 (1:61b8)
	ld a, PLAY_AREA_CARD_LIST
	ld [wDuelDisplayedScreen], a
	call PrintPlayAreaCardList
	call EnableLCD
	ld a, [wNumPlayAreaItems]
	ret
; 0x61c7

; for each turn holder's play area Pokemon card, print the name, level,
; face down stage card, color symbol, status symbol (if any), pluspower/defender
; symbols (if any), attached energies (if any), and HP bar.
; also print the play area locations (ACT/BPx indicators) for each of the six slots.
PrintPlayAreaCardList: ; 61c7 (1:61c7)
	ld a, PLAY_AREA_CARD_LIST
	ld [wDuelDisplayedScreen], a
	ld de, wDuelTempList
	call SetListPointer
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	ld c, a
	ld b, $00
.print_cards_info_loop
	; for each Pokemon card in play area, print its information (and location)
	push hl
	push bc
	ld a, b
	ld [wCurPlayAreaSlot], a
	ld a, b
	add a
	add b
	ld [wCurPlayAreaY], a
	ld a, b
	add DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call SetNextElementOfList
	call PrintPlayAreaCardInformationAndLocation
	pop bc
	pop hl
	inc b
	dec c
	jr nz, .print_cards_info_loop
	push bc
.print_locations_loop
	; print all play area location indicators (even if there's no Pokemon card on it)
	ld a, b
	cp MAX_PLAY_AREA_POKEMON
	jr z, .locations_printed
	ld [wCurPlayAreaSlot], a
	add a
	add b
	ld [wCurPlayAreaY], a
	push bc
	call PrintPlayAreaCardLocation
	pop bc
	inc b
	jr .print_locations_loop
.locations_printed
	pop bc
	ld a, b
	ld [wNumPlayAreaItems], a
	ld a, [wExcludeArenaPokemon]
	or a
	ret z
	; if wExcludeArenaPokemon is set, decrement [wNumPlayAreaItems] and shift back wDuelTempList
	dec b
	ld a, b
	ld [wNumPlayAreaItems], a
	ld hl, wDuelTempList + 1
	ld de, wDuelTempList
.shift_back_loop
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, .shift_back_loop
	ret
; 0x622a

; print a turn holder's play area Pokemon card's name, level, face down stage card,
; color symbol, status symbol (if any), pluspower/defender symbols (if any),
; attached energies (if any), HP bar, and the play area location (ACT/BPx indicator)
; input:
   ; wCurPlayAreaSlot: PLAY_AREA_* of the card to display the information of
   ; wCurPlayAreaY: Y coordinate of where to print the card's information
; total space occupied is a rectangle of 20x3 tiles
PrintPlayAreaCardInformationAndLocation: ; 622a (1:622a)
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	ret z
	call PrintPlayAreaCardInformation
;	fallthrough

;  print a turn holder's play area Pokemon card's location (ACT/BPx indicator)
PrintPlayAreaCardLocation: ; 6238 (1:6238)
	; print the ACT/BPx indicator
	ld a, [wCurPlayAreaSlot]
	add a
	add a
	ld e, a
	ld d, $00
	ld hl, PlayAreaLocationTileNumbers
	add hl, de
	ldh a, [hWhoseTurn]
	cp PLAYER_TURN
	jr z, .write_tiles
	; move forward to the opponent's side tile numbers
	; they have black letters and white background instead of the other way around
	ld d, $0a
.write_tiles
	ld a, [wCurPlayAreaY]
	ld b, 1
	ld c, a
	ld a, [hli]
	add d
	call WriteByteToBGMap0
	inc c
	ld a, [hli]
	add d
	call WriteByteToBGMap0
	inc c
	ld a, [hli]
	add d
	call WriteByteToBGMap0
	ret
; 0x6264

PlayAreaLocationTileNumbers: ; 6264 (1:6264)
	db $e0, $e1, $e2, $00 ; ACT
	db $e3, $e4, $e5, $00 ; BP1
	db $e3, $e4, $e6, $00 ; BP2
	db $e3, $e4, $e7, $00 ; BP3
	db $e3, $e4, $e8, $00 ; BP4
	db $e3, $e4, $e9, $00 ; BP5

; print a turn holder's play area Pokemon card's name, level, face down stage card,
; color symbol, status symbol (if any), pluspower/defender symbols (if any),
; attached energies (if any), and HP bar.
; input:
   ; wCurPlayAreaSlot: PLAY_AREA_* of the card to display the information of
   ; wCurPlayAreaY: Y coordinate of where to print the card's information
; total space occupied is a rectangle of 20x3 tiles
PrintPlayAreaCardInformation: ; 627c (1:627c)
	; print name, level, color, stage, status, pluspower/defender
	call PrintPlayAreaCardHeader
	; print the symbols of the attached energies
	ld a, [wCurPlayAreaSlot]
	ld e, a
	ld a, [wCurPlayAreaY]
	inc a
	ld c, a
	ld b, 7
	call PrintPlayAreaCardAttachedEnergies
	ld a, [wCurPlayAreaY]
	inc a
	ld c, a
	ld b, 5
	ld a, SYM_E
	call WriteByteToBGMap0
	; print the HP bar
	inc c
	ld a, SYM_HP
	call WriteByteToBGMap0
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD_HP
	call GetTurnDuelistVariable
	or a
	jr z, .zero_hp
	ld e, a
	ld a, [wLoadedCard1HP]
	ld d, a
	call DrawHPBar
	ld a, [wCurPlayAreaY]
	inc a
	inc a
	ld c, a
	ld b, 7
	call BCCoordToBGMap0Address
	ld hl, wDefaultText
	ld b, 12
	call SafeCopyDataHLtoDE
	ret
.zero_hp
	; if fainted, print "Knock Out" in place of the HP bar
	ld a, [wCurPlayAreaY]
	inc a
	inc a
	ld e, a
	ld d, 7
	ldtx hl, KnockOutText
	call InitTextPrinting_ProcessTextFromID
	ret
; 0x62d5

; print a turn holder's play area Pokemon card's name, level, face down stage card,
; color symbol, status symbol (if any), and pluspower/defender symbols (if any).
; input:
   ; wCurPlayAreaSlot: PLAY_AREA_* of the card to display the information of
   ; wCurPlayAreaY: Y coordinate of where to print the card's information
PrintPlayAreaCardHeader: ; 62d5 (1:62d5)
	; start by printing the Pokemon's name
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, [wCurPlayAreaY]
	ld e, a
	ld d, 4
	call InitTextPrinting
	; copy the name to wDefaultText (max. 10 characters)
	; then call ProcessText with hl = wDefaultText
	ld hl, wLoadedCard1Name
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld de, wDefaultText
	push de
	ld a, 10 ; card name maximum length
	call CopyTextData_FromTextID
	pop hl
	call ProcessText

	; print the Pokemon's color and the level
	ld a, [wCurPlayAreaY]
	ld c, a
	ld b, 18
	ld a, [wCurPlayAreaSlot]
	call GetPlayAreaCardColor
	inc a
	call JPWriteByteToBGMap0
	ld b, 14
	ld a, SYM_Lv
	call WriteByteToBGMap0
	ld a, [wCurPlayAreaY]
	ld c, a
	ld b, 15
	ld a, [wLoadedCard1Level]
	call WriteTwoDigitNumberInTxSymbolFormat

	; print the 2x2 face down card image depending on the Pokemon's evolution stage
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD_STAGE
	call GetTurnDuelistVariable
	add a
	ld e, a
	ld d, $00
	ld hl, FaceDownCardTileNumbers
	add hl, de
	ld a, [hli] ; starting tile to fill the 2x2 rectangle with
	push hl
	push af
	lb hl, 1, 2
	lb bc, 2, 2
	ld a, [wCurPlayAreaY]
	ld e, a
	ld d, 2
	pop af
	call FillRectangle
	pop hl
	ld a, [wConsole]
	cp CONSOLE_CGB
	jr nz, .not_cgb
	; in cgb, we have to take care of coloring it too
	ld a, [hl]
	lb hl, 0, 0
	lb bc, 2, 2
	call BankswitchVRAM1
	call FillRectangle
	call BankswitchVRAM0

.not_cgb
	; print the status condition symbol if any (only for the arena Pokemon card)
	ld hl, wCurPlayAreaSlot
	ld a, [hli]
	or a
	jr nz, .skip_status
	ld c, [hl]
	inc c
	inc c
	ld b, 2
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	call CheckPrintCnfSlpPrz
	inc b
	call CheckPrintPoisoned
	inc b
	call CheckPrintDoublePoisoned

.skip_status
	; finally check whether to print the Pluspower and/or Defender symbols
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD_ATTACHED_PLUSPOWER
	call GetTurnDuelistVariable
	or a
	jr z, .not_pluspower
	ld a, [wCurPlayAreaY]
	inc a
	ld c, a
	ld b, 15
	ld a, SYM_PLUSPOWER
	call WriteByteToBGMap0
	inc b
	ld a, [hl]
	add SYM_0
	call WriteByteToBGMap0
.not_pluspower
	ld a, [wCurPlayAreaSlot]
	add DUELVARS_ARENA_CARD_ATTACHED_DEFENDER
	call GetTurnDuelistVariable
	or a
	jr z, .not_defender
	ld a, [wCurPlayAreaY]
	inc a
	ld c, a
	ld b, 17
	ld a, SYM_DEFENDER
	call WriteByteToBGMap0
	inc b
	ld a, [hl]
	add SYM_0
	call WriteByteToBGMap0
.not_defender
	ret
; 0x63b3

FaceDownCardTileNumbers: ; 63b3 (1:63b3)
; starting tile number, cgb palette (grey, yellow/red, green/blue, pink/orange)
	db $d0, $02 ; basic
	db $d4, $02 ; stage 1
	db $d8, $01 ; stage 2
	db $dc, $01 ; stage 2 special
; 0x63bb

; given a card's status in a, print the Poison symbol at bc if it's poisoned
CheckPrintPoisoned: ; 63bb (1:63bb)
	push af
	and POISONED
	jr z, .print
.poison
	ld a, SYM_POISONED
.print
	call WriteByteToBGMap0
	pop af
	ret
; 0x63c7

; given a card's status in a, print the Poison symbol at bc if it's double poisoned
CheckPrintDoublePoisoned: ; 63c7 (1:63c7)
	push af
	and DOUBLE_POISONED - POISONED
	jr nz, CheckPrintPoisoned.poison ; double poison (print a second symbol)
	jr CheckPrintPoisoned.print ; not double poisoned
; 0x63ce

; given a card's status in a, print the Confusion, Sleep, or Paralysis symbol at bc
; for each of those status that is active
CheckPrintCnfSlpPrz: ; 63ce (1:63ce)
	push af
	push hl
	push de
	and CNF_SLP_PRZ
	ld e, a
	ld d, $00
	ld hl, .status_symbols
	add hl, de
	ld a, [hl]
	call WriteByteToBGMap0
	pop de
	pop hl
	pop af
	ret

.status_symbols
	;  NO_STATUS, CONFUSED,     ASLEEP,     PARALYZED
	db SYM_SPACE, SYM_CONFUSED, SYM_ASLEEP, SYM_PARALYZED
; 0x63e6

; print the symbols of the attached energies of a turn holder's play area card
; input:
; - e: PLAY_AREA_*
; - b, c: where to print (x, y)
; - wAttachedEnergies and wTotalAttachedEnergies
PrintPlayAreaCardAttachedEnergies: ; 63e6 (1:63e6)
	push bc
	call GetPlayAreaCardAttachedEnergies
	ld hl, wDefaultText
	push hl
	ld c, NUM_TYPES
	xor a
.empty_loop
	ld [hli], a
	dec c
	jr nz, .empty_loop
	pop hl
	ld de, wAttachedEnergies
	lb bc, SYM_FIRE, NUM_TYPES - 1
.next_color
	ld a, [de] ; energy count of current color
	inc de
	inc a
	jr .check_amount
.has_energy
	ld [hl], b
	inc hl
.check_amount
	dec a
	jr nz, .has_energy
	inc b
	dec c
	jr nz, .next_color
	ld a, [wTotalAttachedEnergies]
	cp 9
	jr c, .place_tiles
	ld a, SYM_PLUS
	ld [wDefaultText + 7], a
.place_tiles
	pop bc
	call BCCoordToBGMap0Address
	ld hl, wDefaultText
	ld b, NUM_TYPES
	call SafeCopyDataHLtoDE
	ret
; 0x6423

	INCROM $6423, $6510

; display the screen that prompts the player to use the selected card's
; Pokemon Power. Includes the card's information above, and the Pokemon Power's
; description below.
; input: hTempPlayAreaLocation_ff9d
DisplayUsePokemonPowerScreen: ; 6510 (1:6510)
	ldh a, [hTempPlayAreaLocation_ff9d]
	ld [wCurPlayAreaSlot], a
	xor a
	ld [wCurPlayAreaY], a
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelCheckPokemonScreenTiles
	call PrintPlayAreaCardInformationAndLocation
	lb de, 1, 4
	call InitTextPrinting
	ld hl, wLoadedCard1Move1Name
	call ProcessTextFromPointerToID_InitTextPrinting
	lb de, 1, 6
	ld hl, wLoadedCard1Move1Description
	call PrintMoveOrCardDescription
	ret
; 0x653e

; print the description of a move or of a trainer or energy card
; x,y coordinates of where to start printing the text are given at de
; don't separate lines of text
PrintMoveOrCardDescription: ; 653e (1:653e)
	call SetNoLineSeparation
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call CountLinesOfTextFromID
	cp 7
	jr c, .print
	dec e ; move one line up to fit (assumes it will be enough)
.print
	ld a, 19
	call InitTextPrintingInTextbox
	call ProcessTextFromID
	call SetOneLineSeparation
	ret
; 0x6558

; moves the cards loaded by deck index at hTempRetreatCostCards to the discard pile
DiscardRetreatCostCards: ; 6558 (1:6558)
	ld hl, hTempRetreatCostCards
.discard_loop
	ld a, [hli]
	cp $ff
	ret z
	call PutCardInDiscardPile
	jr .discard_loop
; 0x6564

; moves the discard pile cards that were loaded to hTempRetreatCostCards back to the active Pokemon.
; this exists because they will be discarded again during the call to AttemptRetreat, so
; it prevents the energy cards from being discarded twice.
ReturnRetreatCostCardsToArena: ; 6564 (1:6564)
	ld hl, hTempRetreatCostCards
.loop
	ld a, [hli]
	cp $ff
	ret z
	push hl
	call MoveDiscardPileCardToHand
	call AddCardToHand
	ld e, PLAY_AREA_ARENA
	call PutHandCardInPlayArea
	pop hl
	jr .loop
; 0x657a

; discard retreat cost energy cards and attempt retreat.
; return carry if unable to retreat this turn due to unsuccessful confusion check
AttemptRetreat: ; 657a (1:657a)
	call DiscardRetreatCostCards
	ldh a, [hTemp_ffa0]
	and CNF_SLP_PRZ
	cp CONFUSED
	jr nz, .success
	ldtx de, ConfusionCheckRetreatText
	call TossCoin
	jr c, .success
	ld a, 1
	ld [wGotHeadsFromConfusionCheckDuringRetreat], a
	scf
	ret
.success
	ldh a, [hTempPlayAreaLocation_ffa1]
	ld e, a
	call SwapArenaWithBenchPokemon
	xor a
	ld [wGotHeadsFromConfusionCheckDuringRetreat], a
	ret
; 0x659f

	INCROM $659f, $65b7

; given a number between 0-99 in a, converts it to TX_SYMBOL format, and writes it
; to wStringBuffer + 3 and to the BGMap0 address at bc.
; if the number is between 0-9, the first digit is replaced with SYM_SPACE.
WriteTwoDigitNumberInTxSymbolFormat: ; 65b7 (1:65b7)
	push hl
	push de
	push bc
	ld l, a
	ld h, $00
	call TwoByteNumberToTxSymbol_TrimLeadingZeros_Bank1
	pop bc
	push bc
	call BCCoordToBGMap0Address
	ld hl, wStringBuffer + 3
	ld b, 2
	call SafeCopyDataHLtoDE
	pop bc
	pop de
	pop hl
	ret
; 0x65d1

; convert the number at hl to TX_SYMBOL text format and write it to wStringBuffer
; replace leading zeros with SYM_SPACE
TwoByteNumberToTxSymbol_TrimLeadingZeros_Bank1: ; 65d1 (1:65d1)
	ld de, wStringBuffer
	ld bc, -10000
	call .get_digit
	ld bc, -1000
	call .get_digit
	ld bc, -100
	call .get_digit
	ld bc, -10
	call .get_digit
	ld bc, -1
	call .get_digit
	xor a ; TX_END
	ld [de], a
	ld hl, wStringBuffer
	ld b, 4
.digit_loop
	ld a, [hl]
	cp SYM_0
	jr nz, .done ; jump if not zero
	ld [hl], SYM_SPACE ; trim leading zero
	inc hl
	dec b
	jr nz, .digit_loop
.done
	ret

.get_digit
	ld a, SYM_0 - 1
.substract_loop
	inc a
	add hl, bc
	jr c, .substract_loop
	ld [de], a
	inc de
	ld a, l
	sub c
	ld l, a
	ld a, h
	sbc b
	ld h, a
	ret
; 0x6614

; input d, e: max. HP, current HP
DrawHPBar: ; 6614 (1:6614)
	ld a, MAX_HP
	ld c, SYM_SPACE
	call .fill_hp_bar ; empty bar
	ld a, d
	ld c, SYM_HP_OK
	call .fill_hp_bar ; fill (max. HP) with HP counters
	ld a, d
	sub e
	ld c, SYM_HP_NOK
	; fill (max. HP - current HP) with damaged HP counters
.fill_hp_bar
	or a
	ret z
	ld hl, wDefaultText
	ld b, HP_BAR_LENGTH
.tile_loop
	ld [hl], c
	inc hl
	dec b
	ret z
	sub MAX_HP / HP_BAR_LENGTH
	jr nz, .tile_loop
	ret
; 0x6635

Func_6635: ; 6635 (1:6635)
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	call LoadDuelCardSymbolTiles
	call LoadDuelFaceDownCardTiles
	ld a, [wTempCardID_ccc2]
	ld e, a
	ld d, $00
	call LoadCardDataToBuffer1_FromCardID
	ld a, CARDPAGE_POKEMON_OVERVIEW
	ld [wCardPageNumber], a
	ld hl, wLoadedCard1Move1Name
	ld a, [wSelectedMoveIndex]
	or a
	jr z, .first_move
	ld hl, wLoadedCard1Move2Name
.first_move
	ld e, $01
	call Func_5c33
	lb de, 1, 4
	ld hl, wLoadedMoveDescription
	call PrintMoveOrCardDescription
	ret
; 0x666a

; display card detail when a trainer card is used, and print "Used xxx"
; hTempCardIndex_ff9f contains the card's deck index
DisplayUsedTrainerCardDetailScreen: ; 666a (1:666a)
	ldh a, [hTempCardIndex_ff9f]
	ldtx hl, UsedText
	call DisplayCardDetailScreen
	ret
; 0x6673

; prints the name and description of a trainer card, along with the
; "Used xxx" text in a text box. this function is used to show the player
; the information of a trainer card being used by the opponent.
PrintUsedTrainerCardDescription: ; 6673 (1:6673)
	call EmptyScreen
	call SetNoLineSeparation
	lb de, 1, 1
	call InitTextPrinting
	ld hl, wLoadedCard1Name
	call ProcessTextFromPointerToID
	ld a, 19
	lb de, 1, 3
	call InitTextPrintingInTextbox
	ld hl, wLoadedCard1NonPokemonDescription
	call ProcessTextFromPointerToID
	call SetOneLineSeparation
	ldtx hl, UsedText
	call DrawWideTextBox_WaitForInput
	ret
; 0x669d

; save data of the current duel to sCurrentDuel
; byte 0 is $01, bytes 1 and 2 are the checksum, byte 3 is [wDuelType]
; next $33a bytes come from DuelDataToSave
SaveDuelData: ; 669d (1:669d)
	farcall CommentedOut_1a6cc
	ld de, sCurrentDuel
;	fallthrough

; save data of the current duel to de (in SRAM)
; byte 0 is $01, bytes 1 and 2 are the checksum, byte 3 is [wDuelType]
; next $33a bytes come from DuelDataToSave
SaveDuelDataToDE: ; 66a4 (1:66a4)
	call EnableSRAM
	push de
	inc de
	inc de
	inc de
	inc de
	ld hl, DuelDataToSave
	push de
.save_duel_data_loop
	; start copying data to de = sCurrentDuelData + $1
	ld c, [hl]
	inc hl
	ld b, [hl]
	inc hl
	ld a, c
	or b
	jr z, .data_done
	push hl
	push bc
	ld c, [hl]
	inc hl
	ld b, [hl]
	inc hl
	pop hl
	call CopyDataHLtoDE
	pop hl
	inc hl
	inc hl
	jr .save_duel_data_loop
.data_done
	pop hl
	; save a checksum to hl = sCurrentDuelData + $1
	lb de, $23, $45
	ld bc, $334 ; misses last 6 bytes to calculate checksum
.checksum_loop
	ld a, e
	sub [hl]
	ld e, a
	ld a, [hli]
	xor d
	ld d, a
	dec bc
	ld a, c
	or b
	jr nz, .checksum_loop
	pop hl
	ld a, $01
	ld [hli], a ; sCurrentDuel
	ld [hl], e ; sCurrentDuelChecksum
	inc hl
	ld [hl], d ; sCurrentDuelChecksum
	inc hl
	ld a, [wDuelType]
	ld [hl], a ; sCurrentDuelData
	call DisableSRAM
	ret
; 0x66e9

Func_66e9: ; 66e9 (1:66e9)
	ld hl, sCurrentDuel
	call ValidateSavedDuelData
	ret c
	ld de, sCurrentDuel
	call LoadSavedDuelData
	call Func_3a45
	ret nc
	call Func_3a40
	or a
	ret
; 0x66ff

; load the data saved in sCurrentDuelData to WRAM according to the distribution
; of DuelDataToSave. assumes saved data exists and that the checksum is valid.
LoadSavedDuelData: ; 66ff (1:66ff)
	call EnableSRAM
	inc de
	inc de
	inc de
	inc de
	ld hl, DuelDataToSave
.next_block
	ld c, [hl]
	inc hl
	ld b, [hl]
	inc hl
	ld a, c
	or b
	jr z, .done
	push hl
	push bc
	ld c, [hl]
	inc hl
	ld b, [hl]
	inc hl
	pop hl
.copy_loop
	ld a, [de]
	inc de
	ld [hli], a
	dec bc
	ld a, c
	or b
	jr nz, .copy_loop
	pop hl
	inc hl
	inc hl
	jr .next_block
.done
	call DisableSRAM
	ret
; 0x6729

DuelDataToSave: ; 6729 (1:6729)
;	dw address, number_of_bytes_to_copy
	dw wPlayerDuelVariables, wOpponentDuelVariables - wPlayerDuelVariables
	dw wOpponentDuelVariables, wPlayerDeck - wOpponentDuelVariables
	dw wPlayerDeck, wc500 + $10 - wPlayerDeck
	dw wWhoseTurn, wDuelTheme + $1 - wWhoseTurn
	dw hWhoseTurn, $1
	dw wRNG1, wRNGCounter + $1 - wRNG1
	dw wcda5, $0010
	dw $0000
; 0x6747

; return carry if there is no data saved at sCurrentDuel or if the checksum isn't correct,
; or if the value saved from wDuelType is DUELTYPE_LINK
ValidateSavedNonLinkDuelData: ; 6747 (1:6747)
	call EnableSRAM
	ld hl, sCurrentDuel
	ld a, [sCurrentDuelData]
	call DisableSRAM
	cp DUELTYPE_LINK
	jr nz, ValidateSavedDuelData
	; ignore any saved data of a link duel
	scf
	ret

; return carry if there is no data saved at sCurrentDuel or if the checksum isn't correct
; input: hl = sCurrentDuel
ValidateSavedDuelData: ; 6759 (1:6759)
	call EnableSRAM
	push de
	ld a, [hli]
	or a
	jr z, .no_saved_data
	lb de, $23, $45
	ld bc, $334
	ld a, [hl]
	sub e
	ld e, a
	inc hl
	ld a, [hl]
	xor d
	ld d, a
	inc hl
	inc hl
.loop
	ld a, [hl]
	add e
	ld e, a
	ld a, [hli]
	xor d
	ld d, a
	dec bc
	ld a, c
	or b
	jr nz, .loop
	ld a, e
	or d
	jr z, .ok
.no_saved_data
	scf
.ok
	call DisableSRAM
	pop de
	ret
; 0x6785

; discard data of a duel that was saved by SaveDuelData, by setting the first byte
; of sCurrentDuel to $00, and zeroing the checksum (next two bytes)
DiscardSavedDuelData: ; 6785 (1:6785)
	call EnableSRAM
	ld hl, sCurrentDuel
	xor a
	ld [hli], a
	ld [hli], a
	ld [hl], a
	call DisableSRAM
	ret
; 0x6793

; loads a player deck (sDeck*Cards) from SRAM to wPlayerDeck
; s0b700 determines which sDeck*Cards source (0-3)
LoadPlayerDeck: ; 6793 (1:6793)
	call EnableSRAM
	ld a, [s0b700]
	ld l, a
	ld h, sDeck2Cards - sDeck1Cards
	call HtimesL
	ld de, sDeck1Cards
	add hl, de
	ld de, wPlayerDeck
	ld c, DECK_SIZE
.copy_cards_loop
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, .copy_cards_loop
	call DisableSRAM
	ret
; 0x67b2

; returns carry if wSkipDelayAllowed is non-0 and B is being held in order to branch
; out of the caller's wait frames loop. probably only used for debugging.
CheckSkipDelayAllowed: ; 67b2 (1:67b2)
	ld a, [wSkipDelayAllowed]
	or a
	ret z
	ldh a, [hKeysHeld]
	and B_BUTTON
	ret z
	scf
	ret
; 0x67be

; related to ai taking their turn in a duel
; called multiple times during one ai turn
AIMakeDecision: ; 67be (1:67be)
	ldh [hAIActionTableIndex], a
	ld hl, wSkipDuelistIsThinkingDelay
	ld a, [hl]
	ld [hl], $0
	or a
	jr nz, .skip_delay
.delay_loop
	call DoFrame
	ld a, [wVBlankCounter]
	cp 60
	jr c, .delay_loop

.skip_delay
	ldh a, [hAIActionTableIndex]
	ld hl, wAITurnEnded
	ld [hl], 0
	ld hl, AIActionTable
	call JumpToFunctionInTable
	ld a, [wDuelFinished]
	ld hl, wAITurnEnded
	or [hl]
	jr nz, .turn_ended
	ld a, [wSkipDuelistIsThinkingDelay]
	or a
	ret nz
	ld [wVBlankCounter], a
	ldtx hl, DuelistIsThinkingText
	call DrawWideTextBox_PrintTextNoDelay
	or a
	ret

.turn_ended
	scf
	ret
; 0x67fb

Func_67fb: ; 67fb (1:67fb)
	ld a, 10
.delay_loop
	call DoFrame
	dec a
	jr nz, .delay_loop
	ld [wCurrentDuelMenuItem], a ; 0
.asm_6806
	ld a, PLAYER_TURN
	ldh [hWhoseTurn], a
	ldtx hl, WaitingHandExamineText
	call DrawWideTextBox_PrintTextNoDelay
	call Func_6850
.asm_6813
	call DoFrame
	call Func_683e
	call RefreshMenuCursor
	ldh a, [hKeysPressed]
	bit 0, a
	jr nz, .asm_682e
	ld a, $01
	call Func_6862
	jr nc, .asm_6813
.asm_6829
	call DrawDuelMainScene
	jr .asm_6806
.asm_682e
	ld a, [wCurrentDuelMenuItem]
	or a
	jr z, .asm_6839
	call Func_3096
	jr .asm_6829
.asm_6839
	call Func_434e
	jr .asm_6829
; 0x683e

Func_683e: ; 683e (1:683e)
	ldh a, [hDPadHeld]
	bit 1, a
	ret nz
	and D_LEFT | D_RIGHT
	ret z
	call EraseCursor
	ld hl, wCurrentDuelMenuItem
	ld a, [hl]
	xor $01
	ld [hl], a
;	fallthrough

Func_6850: ; 6850 (1:6850)
	ld d, 2
	ld a, [wCurrentDuelMenuItem]
	or a
	jr z, .set_cursor_params
	ld d, 8
.set_cursor_params
	ld e, 16
	lb bc, SYM_CURSOR_R, SYM_SPACE
	jp SetCursorParametersForTextBox
; 0x6862

Func_6862: ; 6862 (1:6862)
	ld [wcbff], a
	ldh a, [hKeysPressed]
	bit START_F, a
	jr nz, .start_pressed
	bit SELECT_F, a
	jr nz, .select_pressed
	ldh a, [hKeysHeld]
	and B_BUTTON
	ret z
	ldh a, [hKeysPressed]
	bit D_DOWN_F, a
	jr nz, .down_pressed
	bit D_LEFT_F, a
	jr nz, .left_pressed
	bit D_UP_F, a
	jr nz, .up_pressed
	bit D_RIGHT_F, a
	jr nz, .right_pressed
	or a
	ret
.start_pressed
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	cp -1
	jr z, .return_carry
	call GetCardIDFromDeckIndex
	call LoadCardDataToBuffer1_FromCardID
	ld hl, wCurPlayAreaSlot
	xor a
	ld [hli], a
	ld [hl], a ; wCurPlayAreaY
	call Func_576a
.return_carry
	scf
	ret
.select_pressed
	ld a, [wcbff]
	or a
	jr nz, .asm_68ad
	call Func_30a6
	jr .return_carry
.asm_68ad
	call Func_4597
	jr .return_carry
.down_pressed
	call OpenPlayAreaScreen
	jr .return_carry
.left_pressed
	call OpenPlayerDiscardPileScreen
	jr .return_carry
.up_pressed
	call OpenOpponentPlayAreaScreen
	jr .return_carry
.right_pressed
	call OpenOpponentDiscardPileScreen
	jr .return_carry
; 0x68c6

Func_68c6: ; 68c6 (1:68c6)
	call Func_3b31
	ld hl, sp+$00
	ld a, l
	ld [wcbf7], a
	ld a, h
	ld [wcbf7 + 1], a
	ld de, Func_0f1d
	ld hl, wDoFrameFunction
	ld [hl], e
	inc hl
	ld [hl], d
	ret
; 0x68dd

ResetDoFrameFunction_Bank1: ; 68dd (1:68dd)
	xor a
	ld hl, wDoFrameFunction
	ld [hli], a
	ld [hl], a
	ret
; 0x68e4

; print the AttachedEnergyToPokemonText, given the energy card to attach in hTempCardIndex_ff98,
; and the PLAY_AREA_* of the turn holder's Pokemon to attach the energy to in hTempPlayAreaLocation_ff9d
PrintAttachedEnergyToPokemon: ; 68e4 (1:68e4)
	ldh a, [hTempPlayAreaLocation_ff9d]
	add DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call LoadCardNameToTxRam2_b
	ldh a, [hTempCardIndex_ff98]
	call LoadCardNameToTxRam2
	ldtx hl, AttachedEnergyToPokemonText
	call DrawWideTextBox_WaitForInput
	ret
; 0x68fa

; print the PokemonEvolvedIntoPokemonText, given the Pokemon card to evolve in wccee,
; and the evolved Pokemon card in hTempCardIndex_ff98. also play a sound effect.
PrintPokemonEvolvedIntoPokemon: ; 68fa (1:68fa)
	ld a, $5e
	call PlaySFX
	ld a, [wccee]
	call LoadCardNameToTxRam2
	ldh a, [hTempCardIndex_ff98]
	call LoadCardNameToTxRam2_b
	ldtx hl, PokemonEvolvedIntoPokemonText
	call DrawWideTextBox_WaitForInput
	ret
; 0x6911

Func_6911: ; 6911 (1:6911)
	xor a
	ld [wAITurnEnded], a
	xor a
	ld [wSkipDuelistIsThinkingDelay], a
.asm_6919
	ld a, [wSkipDuelistIsThinkingDelay]
	or a
	jr nz, .asm_6932
	call Func_68c6
	call Func_67fb
	ld a, [wDuelDisplayedScreen]
	cp CHECK_PLAY_AREA
	jr nz, .asm_6932
	lb de, $38, $9f
	call SetupText
.asm_6932
	call ResetDoFrameFunction_Bank1
	call SerialRecvDuelData
	ld a, OPPONENT_TURN
	ldh [hWhoseTurn], a
	ld a, [wSerialFlags]
	or a
	jp nz, DuelTransmissionError
	xor a
	ld [wSkipDuelistIsThinkingDelay], a
	ldh a, [hAIActionTableIndex]
	cp $17
	jp nc, DuelTransmissionError
	ld hl, AIActionTable
	call JumpToFunctionInTable
	ld hl, wAITurnEnded
	ld a, [wDuelFinished]
	or [hl]
	jr z, .asm_6919
	ret
; 0x695e

AIActionTable: ; 695e (1:695e)
	dw DuelTransmissionError
	dw AIAction_PlayBenchPokemon
	dw AIAction_EvolvePokemon
	dw AIAction_UseEnergyCard
	dw AIAction_TryRetreat
	dw AIAction_FinishedTurnNoAttack
	dw AIAction_UseTrainerCard
	dw AIAction_TryExecuteEffect
	dw AIAction_Attack
	dw AIAction_AttackEffect
	dw AIAction_AttackDamage
	dw AIAction_DrawCard
	dw AIAction_UsePokemonPower
	dw AIAction_6b07
	dw AIAction_ForceOpponentSwitchActive
	dw AIAction_NoAction
	dw AIAction_NoAction
	dw AIAction_TossCoinATimes
	dw AIAction_6b30
	dw AIAction_NoAction
	dw AIAction_6b3e
	dw AIAction_6b15
	dw AIAction_DrawDuelMainScene

AIAction_DrawCard: ; 698c (1:698c)
	call DrawCardFromDeck
	call nc, AddCardToHand
	ret
; 0x6993

AIAction_FinishedTurnNoAttack: ; 6993 (1:6993)
	call DrawDuelMainScene
	call ClearNonTurnTemporaryDuelvars
	ldtx hl, FinishedTurnWithoutAttackingText
	call DrawWideTextBox_WaitForInput
	ld a, 1
	ld [wAITurnEnded], a
	ret
; 0x69a5

AIAction_UseEnergyCard: ; 69a5 (1:69a5)
	ldh a, [hTempPlayAreaLocation_ffa1]
	ldh [hTempPlayAreaLocation_ff9d], a
	ld e, a
	ldh a, [hTemp_ffa0]
	ldh [hTempCardIndex_ff98], a
	call PutHandCardInPlayArea
	ldh a, [hTemp_ffa0]
	call LoadCardDataToBuffer1_FromDeckIndex
	call DrawLargePictureOfCard
	call PrintAttachedEnergyToPokemon
	ld a, 1
	ld [wAlreadyPlayedEnergy], a
	call DrawDuelMainScene
	ret
; 0x69c5

AIAction_EvolvePokemon: ; 69c5 (1:69c5)
	ldh a, [hTempPlayAreaLocation_ffa1]
	ldh [hTempPlayAreaLocation_ff9d], a
	ldh a, [hTemp_ffa0]
	ldh [hTempCardIndex_ff98], a
	call LoadCardDataToBuffer1_FromDeckIndex
	call DrawLargePictureOfCard
	call EvolvePokemonCard
	call PrintPokemonEvolvedIntoPokemon
	call Func_161e
	call DrawDuelMainScene
	ret
; 0x69e0

AIAction_PlayBenchPokemon: ; 69e0 (1:69e0)
	ldh a, [hTemp_ffa0]
	ldh [hTempCardIndex_ff98], a
	call PutHandPokemonCardInPlayArea
	ldh [hTempPlayAreaLocation_ff9d], a
	add DUELVARS_ARENA_CARD_STAGE
	call GetTurnDuelistVariable
	ld [hl], 0
	ldh a, [hTemp_ffa0]
	ldtx hl, PlacedOnTheBenchText
	call DisplayCardDetailScreen
	call Func_161e
	call DrawDuelMainScene
	ret
; 0x69ff

AIAction_TryRetreat: ; 69ff (1:69ff)
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	push af
	call AttemptRetreat
	ldtx hl, RetreatWasUnsuccessfulText
	jr c, .failed
	xor a
	ld [wDuelDisplayedScreen], a
	ldtx hl, RetreatedToTheBenchText
.failed
	push hl
	call DrawDuelMainScene
	pop hl
	pop af
	push hl
	call LoadCardNameToTxRam2
	pop hl
	call DrawWideTextBox_WaitForInput_Bank1
	ret
; 0x6a23

AIAction_UseTrainerCard: ; 6a23 (1:6a23)
	call LoadNonPokemonCardEffectCommands
	call DisplayUsedTrainerCardDetailScreen
	call PrintUsedTrainerCardDescription
	call ExchangeRNG
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
; 0x6a35

; for trainer card effects
AIAction_TryExecuteEffect: ; 6a35 (1:6a35)
	ld a, $06
	call TryExecuteEffectCommandFunction
	ld a, $03
	call TryExecuteEffectCommandFunction
	call DrawDuelMainScene
	ldh a, [hTempCardIndex_ff9f]
	call MoveHandCardToDiscardPile
	call ExchangeRNG
	call DrawDuelMainScene
	ret
; 0x6a4e

; determine if an attack is successful
; if no, end the turn early
; if yes, AIAction_AttackEffect and AIAction_AttackDamage can be called next
AIAction_Attack: ; 6a4e (1:6a4e)
	ldh a, [hTempCardIndex_ff9f]
	ld d, a
	ldh a, [hTemp_ffa0]
	ld e, a
	call CopyMoveDataAndDamage_FromDeckIndex
	call Func_16f6
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	call CheckSandAttackOrSmokescreenSubstatus
	jr c, .has_status_effect
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	and CNF_SLP_PRZ
	cp CONFUSED
	jr z, .has_status_effect
	call ExchangeRNG
	ret
.has_status_effect
	call DrawDuelMainScene
	call PrintPokemonsAttackText
	call WaitForWideTextBoxInput
	call ExchangeRNG
	call HandleSandAttackOrSmokescreenSubstatus
	ret nc ; attack is successful
	call ClearNonTurnTemporaryDuelvars
	; only end the turn if the attack fails
	ld a, 1
	ld [wAITurnEnded], a
	ret
; 0x6a8c

AIAction_AttackEffect: ; 6a8c (1:6a8c)
	ld a, $06
	call TryExecuteEffectCommandFunction
	call CheckSelfConfusionDamage
	jr c, .confusion_damage
	call Func_6635
	call PrintPokemonsAttackText
	call WaitForWideTextBoxInput
	call ExchangeRNG
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
.confusion_damage
	call DealConfusionDamageToSelf
	; only end the turn if the attack fails
	ld a, 1
	ld [wAITurnEnded], a
	ret
; 0x6ab1

AIAction_AttackDamage: ; 6ab1 (1:6ab1)
	call Func_179a
	ld a, 1
	ld [wAITurnEnded], a
	ret
; 0x6aba

AIAction_ForceOpponentSwitchActive: ; 6aba (1:6aba)
	ldtx hl, SelectPkmnOnBenchToSwitchWithActiveText
	call DrawWideTextBox_WaitForInput
	call SwapTurn
	call HasAlivePokemonOnBench
	ld a, $01
	ld [wcbd4], a
.force_selection
	call OpenPlayAreaScreenForSelection
	jr c, .force_selection
	call SwapTurn
	ldh a, [hTempPlayAreaLocation_ff9d]
	call SerialSendByte
	ret
; 0x6ad9

AIAction_UsePokemonPower: ; 6ad9 (1:6ad9)
	ldh a, [hTempCardIndex_ff9f]
	ld d, a
	ld e, $00
	call CopyMoveDataAndDamage_FromDeckIndex
	ldh a, [hTemp_ffa0]
	ldh [hTempPlayAreaLocation_ff9d], a
	call DisplayUsePokemonPowerScreen
	ldh a, [hTempCardIndex_ff9f]
	call LoadCardNameToTxRam2
	ld hl, wLoadedMoveName
	ld a, [hli]
	ld [wTxRam2_b], a
	ld a, [hl]
	ld [wTxRam2_b + 1], a
	ldtx hl, WillUseThePokemonPowerText
	call DrawWideTextBox_WaitForInput_Bank1
	call ExchangeRNG
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
; 0x6b07

AIAction_6b07: ; 6b07 (1:6b07)
	call Func_7415
	ld a, $03
	call TryExecuteEffectCommandFunction
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
; 0x6b15

AIAction_6b15: ; 6b15 (1:6b15)
	ld a, $04
	call TryExecuteEffectCommandFunction
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
; 0x6b20

AIAction_DrawDuelMainScene: ; 6b20 (1:6b20)
	call DrawDuelMainScene
	ret
; 0x6b24

AIAction_TossCoinATimes: ; 6b24 (1:6b24)
	call SerialRecv8Bytes
	call TossCoinATimes
	ld a, $01
	ld [wSkipDuelistIsThinkingDelay], a
	ret
; 0x6b30

AIAction_6b30: ; 6b30 (1:6b30)
	ldh a, [hWhoseTurn]
	push af
	ldh a, [hTemp_ffa0]
	ldh [hWhoseTurn], a
	call Func_4f2d
	pop af
	ldh [hWhoseTurn], a
	ret
; 0x6b3e

AIAction_6b3e: ; 6b3e (1:6b3e)
	call DrawDuelMainScene
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	and CNF_SLP_PRZ
	cp CONFUSED
	jr z, .asm_6b56
	call PrintPokemonsAttackText
	call .asm_6b56
	call WaitForWideTextBoxInput
	ret
.asm_6b56
	call SerialRecv8Bytes
	push bc
	call SwapTurn
	call CopyMoveDataAndDamage_FromDeckIndex
	call SwapTurn
	ldh a, [hTempCardIndex_ff9f]
	ld [wPlayerAttackingCardIndex], a
	ld a, [wSelectedMoveIndex]
	ld [wPlayerAttackingMoveIndex], a
	ld a, [wTempCardID_ccc2]
	ld [wPlayerAttackingCardID], a
	call Func_16f6
	pop bc
	ld a, c
	ld [wccf0], a
	ret
; 0x6b7d

AIAction_NoAction: ; 6b7d (1:6b7d)
	ret
; 0x6b7e

; load the text ID of the card name with deck index given in a to TxRam2
; also loads the card to wLoadedCard1
LoadCardNameToTxRam2: ; 6b7e (1:6b7e)
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, [wLoadedCard1Name]
	ld [wTxRam2], a
	ld a, [wLoadedCard1Name + 1]
	ld [wTxRam2 + 1], a
	ret
; 0x6b8e

; load the text ID of the card name with deck index given in a to TxRam2_b
; also loads the card to wLoadedCard1
LoadCardNameToTxRam2_b: ; 6b8e (1:6b8e)
	call LoadCardDataToBuffer1_FromDeckIndex
	ld a, [wLoadedCard1Name]
	ld [wTxRam2_b], a
	ld a, [wLoadedCard1Name + 1]
	ld [wTxRam2_b + 1], a
	ret
; 0x6b9e

DrawWideTextBox_WaitForInput_Bank1: ; 6b9e (1:6b9e)
	call DrawWideTextBox_WaitForInput
	ret
; 0x6ba2

Func_6ba2: ; 6ba2 (1:6ba2)
	call DrawWideTextBox_PrintText
	ld a, [wDuelistType]
	cp DUELIST_TYPE_LINK_OPP
	ret z
	call WaitForWideTextBoxInput
	ret
; 0x6baf

; apply and/or refresh status conditions and other events that trigger between turns
HandleBetweenTurnsEvents: ; 6baf (1:6baf)
	call IsArenaPokemonAsleepOrDoublePoisoned
	jr c, .something_to_handle
	cp PARALYZED
	jr z, .something_to_handle
	call SwapTurn
	call IsArenaPokemonAsleepOrDoublePoisoned
	call SwapTurn
	jr c, .something_to_handle
	call DiscardAttachedPluspowers
	call SwapTurn
	call DiscardAttachedDefenders
	call SwapTurn
	ret
.something_to_handle
	; either:
	; 1. turn holder's arena Pokemon is paralyzed, asleep or double poisoned
	; 2. non-turn holder's arena Pokemon is asleep or double poisoned
	call Func_3b21
	call ZeroObjectPositionsAndToggleOAMCopy
	call EmptyScreen
	ld a, BOXMSG_BETWEEN_TURNS
	call DrawDuelBoxMessage
	ldtx hl, BetweenTurnsText
	call DrawWideTextBox_WaitForInput
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call GetCardIDFromDeckIndex
	ld a, e
	ld [wTempNonTurnDuelistCardID], a
	ld l, DUELVARS_ARENA_CARD_STATUS
	ld a, [hl]
	or a
	jr z, .asm_6c1a
	call $6d3f
	jr c, .asm_6c1a
	call Func_6cfa
	ld a, [hl]
	and CNF_SLP_PRZ
	cp PARALYZED
	jr nz, .asm_6c1a
	ld a, DOUBLE_POISONED
	and [hl]
	ld [hl], a
	call Func_6c7e
	ldtx hl, IsCuredOfParalysisText
	call Func_6ce4
	ld a, $3e
	call Func_6cab
	call WaitForWideTextBoxInput
.asm_6c1a
	call DiscardAttachedPluspowers
	call SwapTurn
	ld a, DUELVARS_ARENA_CARD
	call GetTurnDuelistVariable
	call GetCardIDFromDeckIndex
	ld a, e
	ld [wTempNonTurnDuelistCardID], a
	ld l, DUELVARS_ARENA_CARD_STATUS
	ld a, [hl]
	or a
	jr z, .asm_6c3a
	call $6d3f
	jr c, .asm_6c3a
	call Func_6cfa
.asm_6c3a
	call DiscardAttachedDefenders
	call SwapTurn
	call $6e4c
	ret
; 0x6c44

; discard any PLUSPOWER attached to the turn holder's arena and/or bench Pokemon
DiscardAttachedPluspowers: ; 6c44 (1:6c44)
	ld a, DUELVARS_ARENA_CARD_ATTACHED_PLUSPOWER
	call GetTurnDuelistVariable
	ld e, MAX_PLAY_AREA_POKEMON
	xor a
.unattach_pluspower_loop
	ld [hli], a
	dec e
	jr nz, .unattach_pluspower_loop
	ld de, PLUSPOWER
	jp MoveCardToDiscardPileIfInArena
; 0x6c56

; discard any DEFENDER attached to the turn holder's arena and/or bench Pokemon
DiscardAttachedDefenders: ; 6c56 (1:6c56)
	ld a, DUELVARS_ARENA_CARD_ATTACHED_DEFENDER
	call GetTurnDuelistVariable
	ld e, MAX_PLAY_AREA_POKEMON
	xor a
.unattach_defender_loop
	ld [hli], a
	dec e
	jr nz, .unattach_defender_loop
	ld de, DEFENDER
	jp MoveCardToDiscardPileIfInArena
; 0x6c68

; return carry if the turn holder's arena Pokemon card is double poisoned or asleep.
; also, if confused, paralyzed, or asleep, return the status condition in a.
IsArenaPokemonAsleepOrDoublePoisoned: ; 6c68 (1:6c68)
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetTurnDuelistVariable
	or a
	ret z
	and DOUBLE_POISONED
	jr nz, .set_carry
	ld a, [hl]
	and CNF_SLP_PRZ
	cp ASLEEP
	jr z, .set_carry
	or a
	ret
.set_carry
	scf
	ret
; 0x6c7e

Func_6c7e: ; 6c7e (1:6c7e)
	ld a, [wDuelDisplayedScreen]
	cp DUEL_MAIN_SCENE
	jr z, .asm_6c98
	ld hl, wWhoseTurn
	ldh a, [hWhoseTurn]
	cp [hl]
	jp z, DrawDuelMainScene
	call SwapTurn
	call DrawDuelMainScene
	call SwapTurn
	ret
.asm_6c98
	ld hl, wWhoseTurn
	ldh a, [hWhoseTurn]
	cp [hl]
	jp z, DrawDuelHUDs
	call SwapTurn
	call DrawDuelHUDs
	call SwapTurn
	ret
; 0x6cab

Func_6cab: ; 6cab (1:6cab)
	push af
	ld a, [wDuelType]
	or a
	jr nz, .asm_6cc6
	ld a, [wWhoseTurn]
	cp PLAYER_TURN
	jr z, .asm_6cc6
	call SwapTurn
	ldh a, [hWhoseTurn]
	ld [wd4af], a
	call SwapTurn
	jr .asm_6ccb
.asm_6cc6
	ldh a, [hWhoseTurn]
	ld [wd4af], a
.asm_6ccb
	xor a
	ld [wd4b0], a
	ld a, $00
	ld [wd4ae], a
	pop af
	call Func_3b6a
.asm_6cd8
	call DoFrame
	call Func_3b52
	jr c, .asm_6cd8
	call Func_6c7e.asm_6c98
	ret
; 0x6ce4

; prints the name of the card at wTempNonTurnDuelistCardID in a text box
Func_6ce4: ; 6ce4 (1:6ce4)
	push hl
	ld a, [wTempNonTurnDuelistCardID]
	ld e, a
	call LoadCardDataToBuffer1_FromCardID
	ld hl, wLoadedCard1Name
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call LoadTxRam2
	pop hl
	call DrawWideTextBox_PrintText
	ret
; 0x6cfa

Func_6cfa: ; 6cfa (1:6cfa)
	ld a, [hl]
	and CNF_SLP_PRZ
	cp ASLEEP
	ret nz
	push hl
	ld a, [wTempNonTurnDuelistCardID]
	ld e, a
	call LoadCardDataToBuffer1_FromCardID
	ld a, 18
	call CopyCardNameAndLevel
	ld [hl], TX_END
	ld hl, wTxRam2
	xor a
	ld [hli], a
	ld [hl], a
	ldtx de, PokemonsSleepCheckText
	call TossCoin
	ld a, $03
	ldtx hl, IsStillAsleepText
	jr nc, .asm_6d2d
	pop hl
	push hl
	ld a, DOUBLE_POISONED
	and [hl]
	ld [hl], a
	ld a, $3e
	ldtx hl, IsCuredOfSleepText
.asm_6d2d
	push af
	push hl
	call Func_6c7e
	pop hl
	call Func_6ce4
	pop af
	call Func_6cab
	pop hl
	call WaitForWideTextBoxInput
	ret
; 0x6d3f

	INCROM $6d3f, $6d84

; given the deck index of a turn holder's card in register a,
; and a pointer in hl to the wLoadedCard* buffer where the card data is loaded,
; check if the card is Clefairy Doll or Mysterious Fossil, and, if so, convert it
; to a Pokemon card in the wLoadedCard* buffer, using .trainer_to_pkmn_data.
ConvertSpecialTrainerCardToPokemon: ; 6d84 (1:6d84)
	ld c, a
	ld a, [hl]
	cp TYPE_TRAINER
	ret nz ; return if the card is not TRAINER type
	push hl
	ldh a, [hWhoseTurn]
	ld h, a
	ld l, c
	ld a, [hl]
	and CARD_LOCATION_PLAY_AREA
	pop hl
	ret z ; return if the card is not in the arena or bench
	ld a, e
	cp MYSTERIOUS_FOSSIL
	jr nz, .check_for_clefairy_doll
	ld a, d
	cp $00 ; MYSTERIOUS_FOSSIL >> 8
	jr z, .start_ram_data_overwrite
	ret
.check_for_clefairy_doll
	cp CLEFAIRY_DOLL
	ret nz
	ld a, d
	cp $00 ; CLEFAIRY_DOLL >> 8
	ret nz
.start_ram_data_overwrite
	push de
	ld [hl], TYPE_PKMN_COLORLESS
	ld bc, CARD_DATA_HP
	add hl, bc
	ld de, .trainer_to_pkmn_data
	ld c, CARD_DATA_UNKNOWN2 - CARD_DATA_HP
.loop
	ld a, [de]
	inc de
	ld [hli], a
	dec c
	jr nz, .loop
	pop de
	ret

.trainer_to_pkmn_data
    db 10                 ; CARD_DATA_HP
    ds $07                ; CARD_DATA_MOVE1_NAME - (CARD_DATA_HP + 1)
    tx DiscardName        ; CARD_DATA_MOVE1_NAME
    tx DiscardDescription ; CARD_DATA_MOVE1_DESCRIPTION
    ds $03                ; CARD_DATA_MOVE1_CATEGORY - (CARD_DATA_MOVE1_DESCRIPTION + 2)
    db POKEMON_POWER      ; CARD_DATA_MOVE1_CATEGORY
    dw TrainerCardAsPokemonEffectCommands ; CARD_DATA_MOVE1_EFFECT_COMMANDS
    ds $18                ; CARD_DATA_RETREAT_COST - (CARD_DATA_MOVE1_EFFECT_COMMANDS + 2)
    db UNABLE_RETREAT     ; CARD_DATA_RETREAT_COST
    ds $0d                ; PKMN_CARD_DATA_LENGTH - (CARD_DATA_RETREAT_COST + 1)

; this function applies status conditions to the defending Pokemon,
; returned by the effect functions in wEffectFunctionsFeedback
Func_6df1: ; 6df1 (1:6df1)
	xor a
	ld [wPlayerArenaCardLastTurnStatus], a
	ld [wOpponentArenaCardLastTurnStatus], a
	ld hl, wEffectFunctionsFeedbackIndex
	ld a, [hl]
	or a
	ret z
	ld e, [hl]
	ld d, $00
	ld hl, wEffectFunctionsFeedback
	add hl, de
	ld [hl], $00
	call CheckNoDamageOrEffect
	jr c, .no_damage_or_effect
	ld hl, wEffectFunctionsFeedback
.apply_status_loop
	ld a, [hli]
	or a
	jr z, .done
	ld d, a
	call ApplyStatusConditionToArenaPokemon
	jr .apply_status_loop
.done
	scf
	ret
.no_damage_or_effect
	ld a, l
	or h
	call nz, DrawWideTextBox_PrintText
	ld hl, wEffectFunctionsFeedback
.asm_6e23
	ld a, [hli]
	or a
	jr z, .asm_6e37
	ld d, a
	ld a, [wWhoseTurn]
	cp d
	jr z, .asm_6e32
	inc hl
	inc hl
	jr .asm_6e23
.asm_6e32
	call ApplyStatusConditionToArenaPokemon
	jr .asm_6e23
.asm_6e37
	ret
; 0x6e38

; apply the status condition at hl+1 to the arena Pokemon
; discard the arena Pokemon's status conditions contained in the bitmask at hl
ApplyStatusConditionToArenaPokemon: ; 6e38 (1:6e38)
	ld e, DUELVARS_ARENA_CARD_STATUS
	ld a, [de]
	and [hl]
	inc hl
	or [hl]
	ld [de], a
	dec hl
	ld e, DUELVARS_ARENA_CARD_LAST_TURN_STATUS
	ld a, [de]
	and [hl]
	inc hl
	or [hl]
	inc hl
	ld [de], a
	ret
; 0x6e49

Func_6e49: ; 6e49 (1:6e49)
	INCROM $6e49, $700a

; print one of the "There was no effect from" texts depending
; on the value at wccf1 ($00 or a status condition constant)
PrintThereWasNoEffectFromStatusText: ; 700a (1:700a)
	ld a, [wccf1]
	or a
	jr nz, .status
	ld hl, wLoadedMoveName
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call LoadTxRam2
	ldtx hl, ThereWasNoEffectFromTxRam2Text
	ret
.status
	ld c, a
	ldtx hl, ThereWasNoEffectFromPoisonConfusionText
	cp POISONED | CONFUSED
	ret z
	and PSN_DBLPSN
	jr nz, .poison
	ld a, c
	and CNF_SLP_PRZ
	ldtx hl, ThereWasNoEffectFromParalysisText
	cp PARALYZED
	ret z
	ldtx hl, ThereWasNoEffectFromSleepText
	cp ASLEEP
	ret z
	ldtx hl, ThereWasNoEffectFromConfusionText
	ret
.poison
	ldtx hl, ThereWasNoEffectFromPoisonText
	cp POISONED
	ret z
	ldtx hl, ThereWasNoEffectFromToxicText
	ret
; 0x7045

	INCROM $7045, $70aa

; initializes variables when a duel begins, such as zeroing wDuelFinished or wDuelTurns,
; and setting wDuelType based on wPlayerDuelistType and wOpponentDuelistType
InitVariablesToBeginDuel: ; 70aa (1:70aa)
	xor a
	ld [wDuelFinished], a
	ld [wDuelTurns], a
	ld [wcce7], a
	ld a, $ff
	ld [wcc0f], a
	ld [wPlayerAttackingCardIndex], a
	ld [wPlayerAttackingMoveIndex], a
	call EnableSRAM
	ld a, [s0a009]
	ld [wSkipDelayAllowed], a
	call DisableSRAM
	ld a, [wPlayerDuelistType]
	cp DUELIST_TYPE_LINK_OPP
	jr z, .set_duel_type
	bit 7, a ; DUELIST_TYPE_AI_OPP
	jr nz, .set_duel_type
	ld a, [wOpponentDuelistType]
	cp DUELIST_TYPE_LINK_OPP
	jr z, .set_duel_type
	bit 7, a ; DUELIST_TYPE_AI_OPP
	jr nz, .set_duel_type
	xor a
.set_duel_type
	ld [wDuelType], a
	ret
; 0x70e6

; init variables that last a single player's turn
InitVariablesToBeginTurn: ; 70e6 (1:70e6)
	xor a
	ld [wAlreadyPlayedEnergy], a
	ld [wGotHeadsFromConfusionCheckDuringRetreat], a
	ld [wGotHeadsFromSandAttackOrSmokescreenCheck], a
	ldh a, [hWhoseTurn]
	ld [wWhoseTurn], a
	ret
; 0x70f6

; make all Pokemon in the turn holder's play area able to evolve. called from the
; player's second turn on, in order to allow evolution of all Pokemon already played.
SetAllPlayAreaPokemonCanEvolve: ; 70f6 (1:70f6)
	ld a, DUELVARS_NUMBER_OF_POKEMON_IN_PLAY_AREA
	call GetTurnDuelistVariable
	ld c, a
	ld l, DUELVARS_ARENA_CARD_FLAGS_C2
.next_pkmn_loop
	res 5, [hl]
	set CAN_EVOLVE_THIS_TURN_F, [hl]
	inc l
	dec c
	jr nz, .next_pkmn_loop
	ret
; 0x7107

; initializes duel variables such as cards in deck and in hand, or Pokemon in play area
; player turn: [c200, c2ff]
; opponent turn: [c300, c3ff]
InitializeDuelVariables: ; 7107 (1:7107)
	ldh a, [hWhoseTurn]
	ld h, a
	ld l, DUELVARS_DUELIST_TYPE
	ld a, [hl]
	push hl
	push af
	xor a
	ld l, a
.zero_duel_variables_loop
	ld [hl], a
	inc l
	jr nz, .zero_duel_variables_loop
	pop af
	pop hl
	ld [hl], a
	lb bc, DUELVARS_CARD_LOCATIONS, DECK_SIZE
	ld l, DUELVARS_DECK_CARDS
.init_duel_variables_loop
; zero card locations and cards in hand, and init order of cards in deck
	push hl
	ld [hl], b
	ld l, b
	ld [hl], $0
	pop hl
	inc l
	inc b
	dec c
	jr nz, .init_duel_variables_loop
	ld l, DUELVARS_ARENA_CARD
	ld c, 1 + MAX_BENCH_POKEMON + 1
.init_play_area
; initialize to $ff card in arena as well as cards in bench (plus a terminator)
	ld [hl], -1
	inc l
	dec c
	jr nz, .init_play_area
	ret
; 0x7133

; draw [wDuelInitialPrizes] cards from the turn holder's deck and place them as prizes:
; write their deck indexes to DUELVARS_PRIZE_CARDS, set their location to
; CARD_LOCATION_PRIZE, and set [wDuelInitialPrizes] bits of DUELVARS_PRIZES.
InitTurnDuelistPrizes: ; 7133 (1:7133)
	ldh a, [hWhoseTurn]
	ld d, a
	ld e, DUELVARS_PRIZE_CARDS
	ld a, [wDuelInitialPrizes]
	ld c, a
	ld b, 0
.draw_prizes_loop
	call DrawCardFromDeck
	ld [de], a
	inc de
	ld h, d
	ld l, a
	ld [hl], CARD_LOCATION_PRIZE
	inc b
	ld a, b
	cp c
	jr nz, .draw_prizes_loop
	push hl
	ld e, c
	ld d, $00
	ld hl, PrizeBitmasks
	add hl, de
	ld a, [hl]
	pop hl
	ld l, DUELVARS_PRIZES
	ld [hl], a
	ret
; 0x715a

PrizeBitmasks: ; 715a (1:715a)
	db %0, %1, %11, %111, %1111, %11111, %111111
; 0x7161

Func_7161: ; 7161 (1:7161)
	or a
	ret z
	ld c, a
	call CountPrizes
	sub c
	jr nc, .asm_716b
	xor a
.asm_716b
	ld c, a
	ld b, $00
	ld hl, PrizeBitmasks
	add hl, bc
	ld b, [hl]
	ld a, DUELVARS_PRIZES
	call GetTurnDuelistVariable
	ld [hl], b
	ret
; 0x717a

; clear the non-turn holder's duelvars starting at DUELVARS_ARENA_CARD_DISABLED_MOVE_INDEX
; these duelvars only last a two-player turn at most.
ClearNonTurnTemporaryDuelvars: ; 717a (1:717a)
	ld a, DUELVARS_ARENA_CARD_DISABLED_MOVE_INDEX
	call GetNonTurnDuelistVariable
	xor a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hl], a
	ret
; 0x7189

; same as ClearNonTurnTemporaryDuelvars, except the non-turn holder's arena
; Pokemon status condition is copied to wccc5
ClearNonTurnTemporaryDuelvars_CopyStatus: ; 7189 (1:7189)
	ld a, DUELVARS_ARENA_CARD_STATUS
	call GetNonTurnDuelistVariable
	ld [wccc5], a
	call ClearNonTurnTemporaryDuelvars
	ret
; 0x7195

Func_7195: ; 7195 (1:7195)
	ld a, DUELVARS_ARENA_CARD_LAST_TURN_DAMAGE
	call GetNonTurnDuelistVariable
	ld a, [wccef]
	or a
	jr nz, .asm_71a9
	ld a, [wDealtDamage]
	ld [hli], a
	ld a, [wccc0]
	ld [hl], a
	ret
.asm_71a9
	xor a
	ld [hli], a
	ld [hl], a
	ret
; 0x71ad

_TossCoin: ; 71ad (1:71ad)
	ld [wcd9c], a
	ld a, [wDuelDisplayedScreen]
	cp COIN_TOSS
	jr z, .asm_71c1
	xor a
	ld [wcd9f], a
	call EmptyScreen
	call LoadDuelCoinTossResultTiles

.asm_71c1
	ld a, [wcd9f]
	or a
	jr nz, .asm_71ec
	ld a, COIN_TOSS
	ld [wDuelDisplayedScreen], a
	lb de, 0, 12
	lb bc, 20, 6
	ld hl, $0000
	call DrawLabeledTextBox
	call EnableLCD
	lb de, 1, 14
	ld a, 19
	call InitTextPrintingInTextbox
	ld hl, wCoinTossScreenTextID
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call PrintText

.asm_71ec
	ld hl, wCoinTossScreenTextID
	xor a
	ld [hli], a
	ld [hl], a
	call EnableLCD
	ld a, DUELVARS_DUELIST_TYPE
	call GetTurnDuelistVariable
	ld [wcd9e], a
	call ExchangeRNG
	xor a
	ld [wCoinTossNumHeads], a

.asm_7204
	ld a, [wcd9c]
	cp $2
	jr c, .asm_7223
	lb bc, 15, 11
	ld a, [wcd9f]
	inc a
	call WriteTwoDigitNumberInTxSymbolFormat
	ld b, 17
	ld a, SYM_SLASH
	call WriteByteToBGMap0
	inc b
	ld a, [wcd9c]
	call WriteTwoDigitNumberInTxSymbolFormat

.asm_7223
	call Func_3b21
	ld a, $58
	call Func_3b6a
	ld a, [wcd9e]
	or a
	jr z, .asm_7236
	call $7324
	jr .asm_723c

.asm_7236
	call WaitForWideTextBoxInput
	call $72ff

.asm_723c
	call Func_3b21
	ld d, $5a
	ld e, $0
	call UpdateRNGSources
	rra
	jr c, .asm_724d
	ld d, $59
	ld e, $1

.asm_724d
	ld a, d
	call Func_3b6a
	ld a, [wcd9e]
	or a
	jr z, .asm_725e
	ld a, e
	call $7310
	ld e, a
	jr .asm_726c

.asm_725e
	push de
	call DoFrame
	call Func_3b52
	pop de
	jr c, .asm_725e
	ld a, e
	call $72ff

.asm_726c
	ld b, $5c
	ld c, $34
	ld a, e
	or a
	jr z, .asm_727c
	ld b, $5b
	ld c, $30
	ld hl, wCoinTossNumHeads
	inc [hl]

.asm_727c
	ld a, b
	call Func_3b6a
	ld a, [wcd9e]
	or a
	jr z, .asm_728a
	ld a, $1
	xor e
	ld e, a

.asm_728a
	ld d, $54
	ld a, e
	or a
	jr nz, .asm_7292
	ld d, $55

.asm_7292
	ld a, d
	call PlaySFX
	ld a, [wcd9c]
	dec a
	jr z, .asm_72b9
	ld a, c
	push af
	ld e, $0
	ld a, [wcd9f]
.asm_72a3
	cp $a
	jr c, .asm_72ad
	inc e
	inc e
	sub $a
	jr .asm_72a3

.asm_72ad
	add a
	ld d, a
	lb bc, 2, 2
	lb hl, 1, 2
	pop af
	call FillRectangle

.asm_72b9
	ld hl, wcd9f
	inc [hl]
	ld a, [wcd9e]
	or a
	jr z, .asm_72dc
	ld a, [hl]
	ld hl, wcd9c
	cp [hl]
	call z, WaitForWideTextBoxInput
	call $7324
	ld a, [wcd9c]
	ld hl, wCoinTossNumHeads
	or [hl]
	jr nz, .asm_72e2
	call z, WaitForWideTextBoxInput
	jr .asm_72e2

.asm_72dc
	call WaitForWideTextBoxInput
	call $72ff

.asm_72e2
	call Func_3b31
	ld a, [wcd9f]
	ld hl, wcd9c
	cp [hl]
	jp c, .asm_7204
	call ExchangeRNG
	call Func_3b31
	call Func_3b21
	ld a, [wCoinTossNumHeads]
	or a
	ret z
	scf
	ret
; 0x72ff

	INCROM $72ff, $7354

BuildVersion: ; 7354 (1:7354)
	db "VER 12/20 09:36", TX_END

	INCROM $7364, $7415

Func_7415: ; 7415 (1:7415)
	xor a
	ld [wce7e], a
	ret
; 0x741a

Func_741a: ; 741a (1:741a)
	ld hl, wEffectFunctionsFeedbackIndex
	ld a, [hl]
	or a
	ret z
	ld e, a
	ld d, $00
	ld hl, wEffectFunctionsFeedback
	add hl, de
	ld [hl], $00
	ld hl, wEffectFunctionsFeedback
.loop
	ld a, [hli]
	or a
	jr z, .done
	ld d, a
	inc hl
	ld a, [hli]
	ld e, $7e
	cp ASLEEP
	jr z, .got_anim
	ld e, $7d
	cp PARALYZED
	jr z, .got_anim
	ld e, $7b
	cp POISONED
	jr z, .got_anim
	ld e, $7b
	cp DOUBLE_POISONED
	jr z, .got_anim
	ld e, $7c
	cp CONFUSED
	jr nz, .loop
	ldh a, [hWhoseTurn]
	cp d
	jr nz, .got_anim
	ld e, $7f
.got_anim
	ld a, e
	ld [wLoadedMoveAnimation], a
	xor a
	ld [wd4b0], a
	push hl
	farcall $6, $4f9c
	pop hl
	jr .loop
.done
	ret
; 0x7469

Func_7469: ; 7469 (1:7469)
	push hl
	push de
	call Func_7494
	call Func_7484
	pop de
	pop hl
	call SubstractHP
	ld a, [wDuelDisplayedScreen]
	cp DUEL_MAIN_SCENE
	ret nz
	push hl
	push de
	call DrawDuelHUDs
	pop de
	pop hl
	ret
; 0x7484

Func_7484: ; 7484 (1:7484)
	ld a, [wLoadedMoveAnimation]
	or a
	ret z
	push de
.asm_748a
	call DoFrame
	call Func_3b52
	jr c, .asm_748a
	pop de
	ret
; 0x7494

Func_7494: ; 7494 (1:7494)
	ldh a, [hWhoseTurn]
	push af
	push hl
	push de
	push bc
	ld a, [wWhoseTurn]
	ldh [hWhoseTurn], a
	ld a, c
	ld [wce81], a
	ldh a, [hWhoseTurn]
	cp h
	jr z, .asm_74aa
	set 7, b
.asm_74aa
	ld a, b
	ld [wce82], a
	ld a, [wWhoseTurn]
	ld [wce83], a
	ld a, [wTempNonTurnDuelistCardID]
	ld [wce84], a
	ld hl, wce7f
	ld [hl], e
	inc hl
	ld [hl], d
	ld a, [wLoadedMoveAnimation]
	cp $01
	jr nz, .asm_74d1
	ld a, e
	cp $46
	jr c, .asm_74d1
	ld a, $02
	ld [wLoadedMoveAnimation], a
.asm_74d1
	farcall $6, $4f9c
	pop bc
	pop de
	pop hl
	pop af
	ldh [hWhoseTurn], a
	ret
; 0x74dc

	INCROM $74dc, $7571

Func_7571: ; 7571 (1:7571)
	INCROM $7571, $7576

Func_7576: ; 7576 (1:7576)
	farcall $6, $591f
	ret
; 0x757b

	INCROM $757b, $758f

Func_758f: ; 758f (1:758f)
	INCROM $758f, $7594

Func_7594: ; 7594 (1:7594)
	farcall $6, $661f
	ret
; 0x7599

	INCROM $7599, $8000