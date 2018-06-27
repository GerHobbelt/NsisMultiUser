!include un.Utils.nsh

; Variables
Var SemiSilentMode ; installer started uninstaller in semi-silent mode using /SS parameter
Var RunningFromInstaller ; installer started uninstaller using /uninstall parameter

Section "un.Program Files" SectionUninstallProgram
	SectionIn RO

	; Ultra Modern UI modifies shell var context, see http://forums.winamp.com/showthread.php?t=399898
	${if} $MultiUser.InstallMode == "AllUsers"
		SetShellVarContext all
	${else}
		SetShellVarContext current
	${endif}

	!insertmacro MULTIUSER_GetCurrentUserString $0
	
	; InvokeShellVerb only works on existing files, so we call it before deleting the EXE, https://github.com/lordmulder/stdutils/issues/22
	
	; Clean up "Start Menu Icon"
	${if} ${AtLeastWin7}
		${StdUtils.InvokeShellVerb} $1 "$INSTDIR" "${PROGEXE}" ${StdUtils.Const.ShellVerb.UnpinFromStart}
	${else}
		!insertmacro DeleteRetryAbort "$STARTMENU\${PRODUCT_NAME}$0.lnk"
	${endif}

	; Clean up "Quick Launch Icon"
	${if} ${AtLeastWin7}
		${StdUtils.InvokeShellVerb} $1 "$INSTDIR" "${PROGEXE}" ${StdUtils.Const.ShellVerb.UnpinFromTaskbar}
	${else}
		!insertmacro DeleteRetryAbort "$QUICKLAUNCH\${PRODUCT_NAME}.lnk"
	${endif}

	; Try to delete the EXE as the first step - if it's in use, don't remove anything else
	!insertmacro DeleteRetryAbort "$INSTDIR\${PROGEXE}"
	!ifdef LICENSE_FILE
		!insertmacro DeleteRetryAbort "$INSTDIR\${LICENSE_FILE}"
	!endif

	; Clean up "Documentation"
	!insertmacro DeleteRetryAbort "$INSTDIR\readme.txt"

	; Clean up "Program Group" - we check that we created Start menu folder, if $StartMenuFolder is empty, the whole $SMPROGRAMS directory will be removed!
	${if} "$StartMenuFolder" != ""
		RMDir /r "$SMPROGRAMS\$StartMenuFolder"
	${endif}

	; Clean up "Dektop Icon"
	!insertmacro DeleteRetryAbort "$DESKTOP\${PRODUCT_NAME}$0.lnk"
SectionEnd

Section /o "un.Program Settings" SectionRemoveSettings
	; this section is executed only explicitly and shouldn't be placed in SectionUninstallProgram
	DeleteRegKey HKCU "Software\${PRODUCT_NAME}"
SectionEnd

Section "-Uninstall" ; hidden section, must always be the last one!
	Delete "$INSTDIR\${UNINSTALL_FILENAME}" ; we cannot use un.DeleteRetryAbort here - when using the _? parameter the uninstaller cannot delete itself and Delete fails, which is OK
	; remove the directory only if it is empty - the user might have saved some files in it
	RMDir "$INSTDIR"
	
	; Remove the uninstaller from registry as the very last step - if sth. goes wrong, let the user run it again
	!insertmacro MULTIUSER_RegistryRemoveInstallInfo ; Remove registry keys	
SectionEnd

; Modern install component descriptions
!insertmacro MUI_UNFUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionUninstallProgram} "Uninstall ${PRODUCT_NAME} files."
	!insertmacro MUI_DESCRIPTION_TEXT ${SectionRemoveSettings} "Remove ${PRODUCT_NAME} program settings. Select only if you don't plan to use the program in the future."
!insertmacro MUI_UNFUNCTION_DESCRIPTION_END

; Callbacks
Function un.onInit
	${GetParameters} $R0

	${GetOptions} $R0 "/uninstall" $R1
	${ifnot} ${errors}
		StrCpy $RunningFromInstaller 1
	${else}
		StrCpy $RunningFromInstaller 0
	${endif}

	${GetOptions} $R0 "/SS" $R1
	${ifnot} ${errors}
		StrCpy $SemiSilentMode 1
		StrCpy $RunningFromInstaller 1
		SetAutoClose true ; auto close (if no errors) if we are called from the installer; if there are errors, will be automatically set to false
	${else}
		StrCpy $SemiSilentMode 0
	${endif}

	${ifnot} ${UAC_IsInnerInstance}
		${andif} $RunningFromInstaller = 0
		!insertmacro CheckSingleInstance "Setup" "Global" "${SETUP_MUTEX}"
		!insertmacro CheckSingleInstance "Application" "Local" "${APP_MUTEX}"
	${endif}

	!insertmacro MULTIUSER_UNINIT

	!insertmacro UMUI_MULTILANG_GET ; we always get the language, since the outer and inner instance might have different language
FunctionEnd

Function un.PageInstallModeChangeMode
	!insertmacro MUI_STARTMENU_GETFOLDER "" $StartMenuFolder
FunctionEnd

Function un.PageComponentsPre
	${if} $SemiSilentMode = 1
		Abort ; if user is installing, no use to remove program settings anyway (should be compatible with all versions)
	${endif}
FunctionEnd

Function un.PageComponentsShow
	; Show/hide the Back button
	GetDlgItem $0 $HWNDPARENT 3
	ShowWindow $0 $UninstallShowBackButton
FunctionEnd

Function un.onUninstFailed
	${if} $SemiSilentMode = 0
		MessageBox MB_ICONSTOP "${PRODUCT_NAME} ${VERSION} could not be fully uninstalled.$\r$\nPlease, restart Windows and run the uninstaller again." /SD IDOK
	${else}
		MessageBox MB_ICONSTOP "${PRODUCT_NAME} could not be fully installed.$\r$\nPlease, restart Windows and run the setup program again." /SD IDOK
	${endif}
FunctionEnd
