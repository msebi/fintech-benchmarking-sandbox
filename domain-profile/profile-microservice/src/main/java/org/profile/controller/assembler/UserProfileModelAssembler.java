package org.profile.controller.assembler;


import org.profile.controller.dto.UserProfileDto;
import org.profile.domain.UserProfile;
import org.springframework.hateoas.EntityModel;
import org.springframework.hateoas.server.RepresentationModelAssembler;
import org.springframework.stereotype.Component;

@Component
public class UserProfileModelAssembler implements
        RepresentationModelAssembler<UserProfile, EntityModel<UserProfileDto>> {


    @Override
    public EntityModel<UserProfileDto> toModel(UserProfile entity) {
        return null;
    }
}
