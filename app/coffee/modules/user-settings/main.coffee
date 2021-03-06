###
# Copyright (C) 2014 Andrey Antukh <niwi@niwi.be>
# Copyright (C) 2014 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014 David Barragán Merino <bameda@dbarragan.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/user-settings/main.coffee
###

taiga = @.taiga
mixOf = @.taiga.mixOf
sizeFormat = @.taiga.sizeFormat
module = angular.module("taigaUserSettings")
debounce = @.taiga.debounce

#############################################################################
## User settings Controller
#############################################################################

class UserSettingsController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgConfig",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "$tgAuth",
        "$translate"
    ]

    constructor: (@scope, @rootscope, @config, @repo, @confirm, @rs, @params, @q, @location, @navUrls,
                  @auth, @translate) ->
        @scope.sectionName = "USER_SETTINGS.MENU.SECTION_TITLE"

        @scope.project = {}
        @scope.user = @auth.getUser()

        if !@scope.user
            @location.path(@navUrls.resolve("permission-denied"))
            @location.replace()

        @scope.lang = @getLan()

        maxFileSize = @config.get("maxUploadFileSize", null)
        if maxFileSize
            text = @translate.instant("USER_SETTINGS.AVATAR_MAX_SIZE", {"maxFileSize": sizeFormat(maxFileSize)})
            @scope.maxFileSizeMsg = text

        promise = @.loadInitialData()

        promise.then null, @.onInitialDataError.bind(@)

    loadInitialData: ->
        return @rs.locales.list().then (locales) =>
            @scope.locales = locales
            return locales

    openDeleteLightbox: ->
        @rootscope.$broadcast("deletelightbox:new", @scope.user)

    getLan: ->
        return @scope.user.lang ||
               @translate.preferredLanguage()

module.controller("UserSettingsController", UserSettingsController)


#############################################################################
## User Profile Directive
#############################################################################

UserProfileDirective = ($confirm, $auth, $repo, $translate) ->
    link = ($scope, $el, $attrs) ->
        submit = debounce 2000, (event) =>
            event.preventDefault()

            form = $el.find("form").checksley()
            return if not form.validate()

            changeEmail = $scope.user.isAttributeModified("email")
            $scope.user.lang = $scope.lang

            onSuccess = (data) =>
                $auth.setUser(data)

                if changeEmail
                    text = $translate.instant("USER_PROFILE.CHANGE_EMAIL_SUCCESS")
                    $confirm.success(text)
                else
                    $confirm.notify('success')

            onError = (data) =>
                form.setErrors(data)
                $confirm.notify('error', data._error_message)

            $repo.save($scope.user).then(onSuccess, onError)

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgUserProfile", ["$tgConfirm", "$tgAuth", "$tgRepo", "$translate", UserProfileDirective])


#############################################################################
## User Avatar Directive
#############################################################################

UserAvatarDirective = ($auth, $model, $rs, $confirm) ->
    link = ($scope, $el, $attrs) ->
        showSizeInfo = ->
            $el.find(".size-info").removeClass("hidden")

        onSuccess = (response) ->
            user = $model.make_model("users", response.data)
            $auth.setUser(user)
            $scope.user = user

            $el.find('.overlay').addClass('hidden')
            $confirm.notify('success')

        onError = (response) ->
            showSizeInfo() if response.status == 413
            $el.find('.overlay').addClass('hidden')
            $confirm.notify('error', response.data._error_message)

        # Change photo
        $el.on "click", ".js-change-avatar", ->
            $el.find("#avatar-field").click()

        $el.on "change", "#avatar-field", (event) ->
            if $scope.avatarAttachment
                $el.find('.overlay').removeClass('hidden')
                $rs.userSettings.changeAvatar($scope.avatarAttachment).then(onSuccess, onError)

        # Use gravatar photo
        $el.on "click", "a.use-gravatar", (event) ->
            $el.find('.overlay').removeClass('hidden')
            $rs.userSettings.removeAvatar().then(onSuccess, onError)

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgUserAvatar", ["$tgAuth", "$tgModel", "$tgResources", "$tgConfirm", UserAvatarDirective])


#############################################################################
## User Avatar Model Directive
#############################################################################

TaigaAvatarModelDirective = ($parse) ->
    link = ($scope, $el, $attrs) ->
        model = $parse($attrs.tgAvatarModel)
        modelSetter = model.assign

        $el.bind 'change', ->
            $scope.$apply ->
                modelSetter($scope, $el[0].files[0])

    return {link:link}

module.directive('tgAvatarModel', ['$parse', TaigaAvatarModelDirective])
