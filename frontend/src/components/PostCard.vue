<script lang="ts" setup>
import { defineProps, reactive } from 'vue';
import {
  IonCard,
  IonCardHeader,
  IonCardTitle,
  IonCardSubtitle,
  IonImg,
  IonCardContent,
  IonChip,
  IonIcon,
  IonLabel,
} from '@ionic/vue';
import { heartCircleSharp, syncCircleSharp } from 'ionicons/icons';
const props = defineProps({
  item: Object,
});

const userInfo = reactive({
  liked: true,
  reposted: false,
});

const likePost = async () => {
  userInfo.liked = !userInfo.liked;
};

const repost = async () => {
  userInfo.reposted = !userInfo.reposted;
};
</script>

<template>
  <ion-card v-if="props.item">
    <ion-img v-if="props.item.image" :src="props.item.image" :alt="props.item.title" />
    <ion-card-header>
      <ion-card-subtitle>{{ props.item.author }}</ion-card-subtitle>
    </ion-card-header>
    <ion-card-content>
      {{ props.item.description }}

      <hr />
      <ion-chip color="danger" :outline="!userInfo.liked" @click="likePost">
        <ion-icon :icon="heartCircleSharp"></ion-icon>
        <ion-label color="danger">101</ion-label>
      </ion-chip>

      <ion-chip color="success" :outline="!userInfo.reposted" @click="repost">
        <ion-icon :icon="syncCircleSharp"></ion-icon>
        <ion-label color="success">15</ion-label>
      </ion-chip>
    </ion-card-content>
  </ion-card>
</template>
