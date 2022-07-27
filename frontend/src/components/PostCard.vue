<script lang="ts" setup>
import { defineProps } from 'vue';
import { IonCard, IonCardHeader, IonCardTitle, IonCardSubtitle, IonImg } from '@ionic/vue';
const props = defineProps({
  item: Object,
});
</script>

<template>
  <ion-card v-if="props.item">
    <ion-img :src="props.item.image" :alt="props.item.title" />
    <ion-card-header>
      <ion-card-title>{{ props.item.title }}</ion-card-title>
      <ion-card-subtitle style="margin-top: 4.8px">{{ props.item.subtitle }}</ion-card-subtitle>
    </ion-card-header>
  </ion-card>
</template>
