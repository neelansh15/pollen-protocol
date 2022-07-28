<script lang="ts" setup>
import { defineProps } from 'vue';
import {
  IonCard,
  IonCardHeader,
  IonCardTitle,
  IonCardSubtitle,
  IonImg,
  IonCardContent,
} from '@ionic/vue';
const props = defineProps({
  item: Object,
});
</script>

<template>
  <ion-card v-if="props.item">
    <ion-img v-if="props.item.image" :src="props.item.image" :alt="props.item.title" />
    <ion-card-header>
      <ion-card-subtitle>{{ props.item.author }}</ion-card-subtitle>
    </ion-card-header>
    <ion-card-content>
      {{ props.item.description }}
    </ion-card-content>
  </ion-card>
</template>
